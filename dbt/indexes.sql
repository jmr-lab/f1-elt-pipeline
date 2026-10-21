-- ============================================================
-- CREATE INDEXES
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_round_season ON round(season_id);
CREATE INDEX IF NOT EXISTS idx_round_circuit ON round(circuit_id);
CREATE INDEX IF NOT EXISTS idx_session_round ON session(round_id);
CREATE INDEX IF NOT EXISTS idx_session_type ON session(type);
CREATE INDEX IF NOT EXISTS idx_session_entry_session ON session_entry(session_id);
CREATE INDEX IF NOT EXISTS idx_session_entry_position ON session_entry(position);
CREATE INDEX IF NOT EXISTS idx_driver_season_driver ON driver_season(driver_id);
CREATE INDEX IF NOT EXISTS idx_driver_season_year ON driver_season(season_id);
CREATE INDEX IF NOT EXISTS idx_constructor_season_constructor ON constructor_season(constructor_id);
CREATE INDEX IF NOT EXISTS idx_constructor_season_year ON constructor_season(season_id);
CREATE INDEX IF NOT EXISTS idx_constructor_engine_constructor ON constructor_engine(constructor_id);
CREATE INDEX IF NOT EXISTS idx_constructor_driver_season ON constructor_driver(season_id);
CREATE INDEX IF NOT EXISTS idx_constructor_driver_driver ON constructor_driver(driver_id);
CREATE INDEX IF NOT EXISTS idx_driver_champ_driver ON driver_championship(driver_id);
CREATE INDEX IF NOT EXISTS idx_driver_champ_season ON driver_championship(season_id);
CREATE INDEX IF NOT EXISTS idx_constructor_champ_constructor ON constructor_championship(constructor_id);
CREATE INDEX IF NOT EXISTS idx_lap_session_entry ON lap(session_entry_id, number);
CREATE INDEX IF NOT EXISTS idx_pitstop_session_entry ON pit_stop(session_entry_id);
CREATE INDEX IF NOT EXISTS idx_points_system_id ON points_system(id);
CREATE INDEX IF NOT EXISTS idx_championship_system_id ON championship_system(id);
