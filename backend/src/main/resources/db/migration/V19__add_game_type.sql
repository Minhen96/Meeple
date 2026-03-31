ALTER TABLE games ADD COLUMN game_type VARCHAR(30) DEFAULT 'boardgame';
CREATE INDEX idx_games_type ON games (game_type);
