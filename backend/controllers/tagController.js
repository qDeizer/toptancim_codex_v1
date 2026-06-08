const db = require('../db');
const generateId = require('../utils/generateId');

const createTag = async (req, res) => {
    const { name, note, pricing_percentage, pricing_delta } = req.body;
    const creator_id = req.user.id;

    if (!name) {
        return res.status(400).json({ message: 'Tag name is required.' });
    }

    try {
        const tag_id = generateId('tag', 8);
        const newTag = await db.query(
            `INSERT INTO tags (tag_id, name, note, pricing_percentage, pricing_delta, creator_id) 
             VALUES ($1, $2, $3, $4, $5, $6) RETURNING *`,
            [tag_id, name, note, pricing_percentage || null, pricing_delta || null, creator_id]
        );
        res.status(201).json(newTag.rows[0]);
    } catch (error) {
        console.error('Create tag error:', error);
        if (error.code === '23505') { // unique_violation
            return res.status(409).json({ message: 'You already have a tag with this name.' });
        }
        res.status(500).json({ message: 'Server error' });
    }
};

const getAllTags = async (req, res) => {
    const creator_id = req.user.id;
    try {
        const tags = await db.query('SELECT * FROM tags WHERE creator_id = $1 ORDER BY name ASC', [creator_id]);
        res.json(tags.rows);
    } catch (error) {
        console.error('Get all tags error:', error);
        res.status(500).json({ message: 'Server error' });
    }
};

const updateTag = async (req, res) => {
    const { id } = req.params;
    const { name, note, pricing_percentage, pricing_delta } = req.body;
    const creator_id = req.user.id;

    if (!name) {
        return res.status(400).json({ message: 'Tag name is required.' });
    }

    try {
        const updatedTag = await db.query(
            `UPDATE tags SET name = $1, note = $2, pricing_percentage = $3, pricing_delta = $4, updated_at = NOW()
             WHERE tag_id = $5 AND creator_id = $6 RETURNING *`,
            [name, note, pricing_percentage || null, pricing_delta || null, id, creator_id]
        );

        if (updatedTag.rowCount === 0) {
            return res.status(404).json({ message: 'Tag not found or you do not have permission to edit it.' });
        }
        res.json(updatedTag.rows[0]);
    } catch (error) {
        console.error('Update tag error:', error);
         if (error.code === '23505') { // unique_violation
            return res.status(409).json({ message: 'You already have another tag with this name.' });
        }
        res.status(500).json({ message: 'Server error' });
    }
};

const deleteTag = async (req, res) => {
    const { id } = req.params;
    const creator_id = req.user.id;
    try {
        const deleteResult = await db.query(
            'DELETE FROM tags WHERE tag_id = $1 AND creator_id = $2',
            [id, creator_id]
        );
        if (deleteResult.rowCount === 0) {
            return res.status(404).json({ message: 'Tag not found or you do not have permission to delete it.' });
        }
        res.json({ message: 'Tag deleted successfully.' });
    } catch (error) {
        console.error('Delete tag error:', error);
        res.status(500).json({ message: 'Server error' });
    }
};

module.exports = {
    createTag,
    getAllTags,
    updateTag,
    deleteTag,
};