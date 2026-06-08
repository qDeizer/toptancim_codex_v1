import json
import os
import sys

import pandas as pd
import psycopg2
from dotenv import load_dotenv
from sklearn.neighbors import NearestNeighbors

env_path = os.path.join(os.path.dirname(__file__), '../.env')
load_dotenv(env_path)


def get_db_connection():
    return psycopg2.connect(
        host=os.getenv('DB_HOST', 'localhost'),
        database=os.getenv('DB_DATABASE', 'toptancimdb_codex'),
        user=os.getenv('DB_USER', 'postgres'),
        password=os.getenv('DB_PASSWORD', 'postgres'),
        port=os.getenv('DB_PORT', '5432')
    )


def load_args():
    if len(sys.argv) < 2:
        raise ValueError('Arguman eksik')
    return json.loads(sys.argv[1])


def load_sales_dataframe(connection):
    query = """
        SELECT
            wholesaler_id,
            customer_id,
            customer_role,
            customer_lat,
            customer_lng,
            product_name,
            quantity,
            line_total,
            sale_date
        FROM ml_sales_view
    """
    return pd.read_sql_query(query, connection)


def resolve_dataset(df, args):
    requester_user_id = args.get('requester_user_id')
    target_user_id = args.get('target_user_id')
    scope_mode = args.get('scope_mode', 'self')

    if df.empty:
        return df.copy(), None

    requester_wholesaler_df = df[df['wholesaler_id'] == requester_user_id].copy()
    requester_customer_df = df[df['customer_id'] == requester_user_id].copy()

    if scope_mode == 'pair' and target_user_id:
        requester_to_target = df[
            (df['wholesaler_id'] == requester_user_id) &
            (df['customer_id'] == target_user_id)
        ].copy()
        target_to_requester = df[
            (df['wholesaler_id'] == target_user_id) &
            (df['customer_id'] == requester_user_id)
        ].copy()

        if not requester_to_target.empty:
            return requester_wholesaler_df, target_user_id

        if not target_to_requester.empty:
            target_wholesaler_df = df[df['wholesaler_id'] == target_user_id].copy()
            return target_wholesaler_df, requester_user_id

        pair_scope_df = df[
            df['wholesaler_id'].isin([requester_user_id, target_user_id]) |
            df['customer_id'].isin([requester_user_id, target_user_id])
        ].copy()

        if target_user_id in pair_scope_df['customer_id'].values:
            return pair_scope_df, target_user_id
        if requester_user_id in pair_scope_df['customer_id'].values:
            return pair_scope_df, requester_user_id
        return pair_scope_df, None

    if not requester_wholesaler_df.empty:
        return requester_wholesaler_df, None

    if not requester_customer_df.empty:
        primary_wholesaler = requester_customer_df['wholesaler_id'].mode().iloc[0]
        dataset = df[df['wholesaler_id'] == primary_wholesaler].copy()
        return dataset, requester_user_id

    return df[
        (df['wholesaler_id'] == requester_user_id) |
        (df['customer_id'] == requester_user_id)
    ].copy(), None


def build_customer_profiles(dataset):
    if dataset.empty:
        return pd.DataFrame()

    profiles = dataset.groupby('customer_id').agg(
        customer_role=('customer_role', lambda values: values.dropna().mode().iloc[0] if not values.dropna().empty else 'bilinmiyor'),
        customer_lat=('customer_lat', 'median'),
        customer_lng=('customer_lng', 'median')
    ).reset_index()

    profiles['customer_role'] = profiles['customer_role'].fillna('bilinmiyor')
    profiles['customer_lat'] = profiles['customer_lat'].astype(float)
    profiles['customer_lng'] = profiles['customer_lng'].astype(float)

    median_lat = profiles['customer_lat'].median()
    median_lng = profiles['customer_lng'].median()
    profiles['customer_lat'] = profiles['customer_lat'].fillna(median_lat if pd.notna(median_lat) else 0.0)
    profiles['customer_lng'] = profiles['customer_lng'].fillna(median_lng if pd.notna(median_lng) else 0.0)

    return profiles


def select_neighbor_customer_ids(dataset, anchor_customer_id):
    profiles = build_customer_profiles(dataset)
    if profiles.empty:
        return []

    features = pd.concat(
        [
            profiles[['customer_lat', 'customer_lng']].reset_index(drop=True),
            pd.get_dummies(profiles['customer_role'], prefix='role')
        ],
        axis=1
    )

    if anchor_customer_id and anchor_customer_id in profiles['customer_id'].values and len(profiles) > 1:
        anchor_index = profiles.index[profiles['customer_id'] == anchor_customer_id][0]
        model = NearestNeighbors(
            n_neighbors=min(6, len(profiles)),
            metric='euclidean'
        )
        model.fit(features.values)
        indices = model.kneighbors(
            features.iloc[[anchor_index]].values,
            return_distance=False
        )[0]
        neighbor_ids = profiles.iloc[indices]['customer_id'].tolist()
        return [customer_id for customer_id in neighbor_ids if customer_id != anchor_customer_id]

    totals = dataset.groupby('customer_id')['quantity'].sum().sort_values(ascending=False)
    return totals.head(5).index.tolist()


def build_recommendations(dataset, neighbor_customer_ids):
    source_df = dataset.copy()
    if neighbor_customer_ids:
        filtered = dataset[dataset['customer_id'].isin(neighbor_customer_ids)].copy()
        if not filtered.empty:
            source_df = filtered

    if source_df.empty:
        return []

    recommendations = source_df.groupby('product_name').agg(
        total_quantity=('quantity', 'sum'),
        total_revenue=('line_total', 'sum')
    ).reset_index()

    recommendations = recommendations.sort_values(
        by=['total_quantity', 'total_revenue'],
        ascending=[False, False]
    ).head(5)

    return recommendations.to_dict('records')


def main():
    try:
        args = load_args()
        connection = get_db_connection()
        df = load_sales_dataframe(connection)
        connection.close()

        if df.empty:
            print(json.dumps({
                'success': False,
                'error': 'Analiz icin yeterli satis verisi yok.'
            }))
            return

        dataset, anchor_customer_id = resolve_dataset(df, args)

        requested_role = args.get('customer_role')
        if requested_role:
            filtered_dataset = dataset[
                dataset['customer_role'].fillna('').str.lower() == requested_role.lower()
            ].copy()
            if not filtered_dataset.empty:
                dataset = filtered_dataset

        if dataset.empty:
            print(json.dumps({
                'success': False,
                'error': 'Secili kapsama ait uygun musteri verisi bulunamadi.'
            }))
            return

        neighbor_customer_ids = select_neighbor_customer_ids(dataset, anchor_customer_id)
        recommendations = build_recommendations(dataset, neighbor_customer_ids)

        print(json.dumps({
            'success': True,
            'analysis_type': 'NearestNeighbors',
            'scope_mode': args.get('scope_mode', 'self'),
            'anchor_customer_id': anchor_customer_id,
            'neighbor_customer_ids': neighbor_customer_ids,
            'dataset_customer_count': int(dataset['customer_id'].nunique()),
            'recommendations': recommendations
        }))
    except Exception as exc:
        print(json.dumps({
            'success': False,
            'error': str(exc)
        }))


if __name__ == '__main__':
    main()
