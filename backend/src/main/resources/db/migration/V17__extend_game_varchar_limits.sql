-- Expand length constraints for extremely long board game titles and image URLs found in the Kaggle dataset
ALTER TABLE games ALTER COLUMN name_en TYPE TEXT;
ALTER TABLE games ALTER COLUMN name_zh TYPE TEXT;
ALTER TABLE games ALTER COLUMN image_url TYPE TEXT;
ALTER TABLE games ALTER COLUMN thumbnail_url TYPE TEXT;

ALTER TABLE game_details ALTER COLUMN bgg_url TYPE TEXT;
