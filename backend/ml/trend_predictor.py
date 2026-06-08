import json
import os
import sys

import pandas as pd
import psycopg2
from dotenv import load_dotenv
from sklearn.linear_model import LinearRegression

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
            product_name,
            quantity,
            line_total,
            sale_date
        FROM ml_sales_view
        WHERE quantity > 0
    """
    return pd.read_sql_query(query, connection)


def apply_scope(df, args):
    requester_user_id = args.get('requester_user_id')
    target_user_id = args.get('target_user_id')
    scope_mode = args.get('scope_mode', 'self')

    if scope_mode == 'pair' and target_user_id:
        return df[
            ((df['wholesaler_id'] == requester_user_id) & (df['customer_id'] == target_user_id)) |
            ((df['wholesaler_id'] == target_user_id) & (df['customer_id'] == requester_user_id))
        ].copy()

    return df[
        (df['wholesaler_id'] == requester_user_id) |
        (df['customer_id'] == requester_user_id)
    ].copy()


def build_daily_series(df):
    daily = df.copy()
    daily['sale_day'] = pd.to_datetime(daily['sale_date']).dt.floor('D')
    daily = daily.groupby('sale_day')['quantity'].sum().reset_index()

    full_range = pd.date_range(daily['sale_day'].min(), daily['sale_day'].max(), freq='D')
    daily = daily.set_index('sale_day').reindex(full_range, fill_value=0).rename_axis('sale_day').reset_index()
    daily['day_index'] = range(len(daily))
    return daily


def main():
    try:
        args = load_args()
        period_days = int(args.get('period_days', 30))
        product_name = args.get('product_name')

        connection = get_db_connection()
        df = load_sales_dataframe(connection)
        connection.close()

        df = apply_scope(df, args)
        if df.empty:
            print(json.dumps({
                'success': False,
                'error': 'Secili kapsam icin tahmin yapilacak satis verisi bulunamadi.'
            }))
            return

        if product_name:
            df = df[
                df['product_name'].fillna('').str.contains(product_name, case=False, na=False)
            ].copy()

        if df.empty:
            print(json.dumps({
                'success': False,
                'error': f"'{product_name}' icin kapsam dahilinde veri bulunamadi."
            }))
            return

        daily = build_daily_series(df)
        historical_total = float(df['quantity'].sum())
        average_daily_sales = float(daily['quantity'].mean())

        if len(daily) >= 2:
            model = LinearRegression()
            model.fit(daily[['day_index']], daily['quantity'])

            future_indices = pd.DataFrame({
                'day_index': range(len(daily), len(daily) + period_days)
            })
            predicted_values = model.predict(future_indices)
            predicted_values = [max(0.0, float(value)) for value in predicted_values]
            estimated_next_period_sales = round(sum(predicted_values), 2)
            trend_slope = float(model.coef_[0])
        else:
            estimated_next_period_sales = round(average_daily_sales * period_days, 2)
            trend_slope = 0.0

        print(json.dumps({
            'success': True,
            'analysis_type': 'LinearRegression',
            'scope_mode': args.get('scope_mode', 'self'),
            'product_name': product_name,
            'period_days': period_days,
            'historical_total_quantity': historical_total,
            'average_daily_sales': round(average_daily_sales, 2),
            'estimated_next_period_sales': estimated_next_period_sales,
            'trend_direction': 'yukselis' if trend_slope > 0.05 else 'dusuk' if trend_slope < -0.05 else 'stabil'
        }))
    except Exception as exc:
        print(json.dumps({
            'success': False,
            'error': str(exc)
        }))


if __name__ == '__main__':
    main()
