-- Extend the numerical precision boundaries for properties that can have highly variant or wildly corrupted scale inputs in the Kaggle dataset
ALTER TABLE games ALTER COLUMN bgg_rating TYPE DECIMAL(10, 4);
ALTER TABLE game_details ALTER COLUMN complexity TYPE DECIMAL(10, 4);
ALTER TABLE game_details ALTER COLUMN std_deviation TYPE DECIMAL(10, 4);
