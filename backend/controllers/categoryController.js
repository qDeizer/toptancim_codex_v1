const db = require('../db');
const generateId = require('../utils/generateId');

const createCategory = async (req, res) => {
    const { name } = req.body;
    const creator_id = req.user.id;

    if (!name) {
        return res.status(400).json({ message: 'Category name is required.' });
    }

    try {
        const existingCategory = await db.query(
            'SELECT * FROM categories WHERE name = $1 AND creator_id = $2',
            [name, creator_id]
        );

        if (existingCategory.rows.length > 0) {
            return res.status(409).json({ message: 'You already have a category with this name.' });
        }

        const category_id = generateId('cat', 8);
        const newCategory = await db.query(
            'INSERT INTO categories (category_id, name, creator_id) VALUES ($1, $2, $3) RETURNING *',
            [category_id, name, creator_id]
        );
        res.status(201).json(newCategory.rows[0]);
    } catch (error) {
        console.error('Create category error:', error);
        res.status(500).json({ message: 'Server error' });
    }
};

const getAllCategories = async (req, res) => {
    const creator_id = req.user.id;
    try {
        const categories = await db.query('SELECT * FROM categories WHERE creator_id = $1 ORDER BY name ASC', [creator_id]);
        res.json(categories.rows);
    } catch (error) {
        console.error('Get all categories error:', error);
        res.status(500).json({ message: 'Server error' });
    }
};

const deleteCategory = async (req, res) => {
    const { id } = req.params;
    const creator_id = req.user.id;
    try {
        const deleteResult = await db.query(
            'DELETE FROM categories WHERE category_id = $1 AND creator_id = $2 RETURNING *',
            [id, creator_id]
        );
        if (deleteResult.rowCount === 0) {
            return res.status(404).json({ message: 'Category not found or you do not have permission to delete it.' });
        }
        res.json({ message: 'Category deleted successfully.' });
    } catch (error) {
        console.error('Delete category error:', error);
        if (error.code === '23503') {
             return res.status(400).json({ message: 'Cannot delete category. It is currently associated with one or more products.' });
        }
        res.status(500).json({ message: 'Server error' });
    }
};

module.exports = {
    createCategory,
    getAllCategories,
    deleteCategory,
};