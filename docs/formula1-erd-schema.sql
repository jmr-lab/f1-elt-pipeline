-- Reference tables (no FKs)
CREATE TABLE countries (
  id INTEGER PRIMARY KEY,
  country_code TEXT NOT NULL UNIQUE,
  country TEXT NOT NULL
);

CREATE TABLE championship_system (
  id INTEGER PRIMARY KEY,
  name TEXT,
  reference TEXT,
  driver_best_results INT,
  team_best_results INT,
  driver_season_split INT,
  team_season_split INT,
  team_points_per_session INT,
  eligibility TEXT
);

CREATE TABLE points_system (
  id INTEGER PRIMARY KEY,
  name TEXT,
  reference TEXT,
  partial INT,
  driver_position_points INT,
  driver_fastest_lap INT,
  team_position_points INT,
  team_fastest_lap INT,
  shared_drive INT,
  is_double_points INT
);

-- Dimension tables
CREATE TABLE circuit (
  id INTEGER PRIMARY KEY,
  name TEXT NOT NULL,
  reference TEXT,
  locality TEXT,
  country TEXT,
  country_code TEXT REFERENCES countries(country_code),
  latitude REAL,
  longitude REAL,
  altitude INT,
  wikipedia TEXT
);

CREATE TABLE base_team (
  id INTEGER PRIMARY KEY,
  name TEXT
);

CREATE TABLE driver (
  id INTEGER PRIMARY KEY,
  reference TEXT,
  abbreviation TEXT,
  forename TEXT,
  surname TEXT,
  country_code TEXT REFERENCES countries(country_code),
  date_of_birth DATE,
  permanent_car_number INT,
  wikipedia TEXT
);

CREATE TABLE team (
  id INTEGER PRIMARY KEY,
  name TEXT NOT NULL,
  reference TEXT,
  country_code TEXT REFERENCES countries(country_code),
  base_team_id INT REFERENCES base_team(id),
  primary_color TEXT,
  wikipedia TEXT
);

CREATE TABLE season (
  id INTEGER PRIMARY KEY,
  year INT NOT NULL UNIQUE,
  championship_system_id INT REFERENCES championship_system(id),
  wikipedia TEXT
);

CREATE TABLE round (
  id INTEGER PRIMARY KEY,
  season_id INT NOT NULL REFERENCES season(id),
  circuit_id INT REFERENCES circuit(id),
  number INT,
  race_number INT,
  name TEXT,
  date DATE,
  is_cancelled INT DEFAULT 0,
  wikipedia TEXT
);

CREATE TABLE session (
  id INTEGER PRIMARY KEY,
  round_id INT NOT NULL REFERENCES round(id),
  type TEXT NOT NULL,
  number INT,
  timestamp TIMESTAMP,
  timezone TEXT,
  scheduled_laps INT,
  point_system_id INT REFERENCES points_system(id),
  is_cancelled INT DEFAULT 0,
  has_time_data INT DEFAULT 0
);

-- Junction/relationship tables
CREATE TABLE team_driver (
  id INTEGER PRIMARY KEY,
  season_id INT NOT NULL REFERENCES season(id),
  team_id INT NOT NULL REFERENCES team(id),
  driver_id INT NOT NULL REFERENCES driver(id),
  role TEXT,
  UNIQUE(season_id, team_id, driver_id)
);

CREATE TABLE season_driver (
  id INTEGER PRIMARY KEY,
  season_id INT NOT NULL REFERENCES season(id),
  driver_id INT NOT NULL REFERENCES driver(id),
  country_id INT REFERENCES countries(id)
);

CREATE TABLE season_team (
  id INTEGER PRIMARY KEY,
  season_id INT NOT NULL REFERENCES season(id),
  team_id INT NOT NULL REFERENCES team(id),
  country_id INT REFERENCES countries(id),
  name TEXT
);

CREATE TABLE roundentry (
  id INTEGER PRIMARY KEY,
  round_id INT NOT NULL REFERENCES round(id),
  team_driver_id INT NOT NULL REFERENCES team_driver(id),
  car_number INT
);

-- Session-level transactional tables
CREATE TABLE session_entry (
  id INTEGER PRIMARY KEY,
  session_id INT NOT NULL REFERENCES session(id),
  round_entry_id INT NOT NULL REFERENCES roundentry(id),
  grid INT,
  position INT,
  points REAL,
  laps_completed INT,
  fastest_lap_rank INT,
  time TEXT,
  detail TEXT,
  status TEXT,
  is_classified INT DEFAULT 0,
  is_eligible_for_points INT DEFAULT 0
);

CREATE TABLE lap (
  id INTEGER PRIMARY KEY,
  session_entry_id INT NOT NULL REFERENCES session_entry(id),
  number INT,
  position INT,
  time TEXT,
  average_speed TEXT,
  is_entry_fastest_lap INT DEFAULT 0,
  is_deleted INT DEFAULT 0
);

CREATE TABLE pit_stop (
  id INTEGER PRIMARY KEY,
  session_entry_id INT NOT NULL REFERENCES session_entry(id),
  lap_id INT REFERENCES lap(id),
  number INT,
  duration TEXT,
  local_timestamp TEXT
);

-- Championship/standings tables
CREATE TABLE driver_championship (
  id INTEGER PRIMARY KEY,
  season_id INT NOT NULL REFERENCES season(id),
  year INT NOT NULL,
  driver_id INT NOT NULL REFERENCES driver(id),
  round_id INT REFERENCES round(id),
  position INT,
  points REAL,
  win_count INT DEFAULT 0,
  highest_finish INT,
  is_eligible INT DEFAULT 1,
  adjustment_type TEXT,
  session_id INT REFERENCES session(id),
  session_number INT,
  round_number INT
);

CREATE TABLE team_championship (
  id INTEGER PRIMARY KEY,
  season_id INT NOT NULL REFERENCES season(id),
  year INT NOT NULL,
  team_id INT NOT NULL REFERENCES team(id),
  round_id INT REFERENCES round(id),
  position INT,
  points REAL,
  win_count INT DEFAULT 0,
  highest_finish INT,
  is_eligible INT DEFAULT 1,
  adjustment_type TEXT,
  session_id INT REFERENCES session(id),
  session_number INT,
  round_number INT
);

CREATE TABLE championship_adjustment (
  id INTEGER PRIMARY KEY,
  adjustment INT,
  driver_id INT REFERENCES driver(id),
  points REAL,
  season_id INT REFERENCES season(id),
  team_id INT REFERENCES team(id)
);

-- Corrections/audit tables
CREATE TABLE driver_nationality_corrections (
  driver_id INT NOT NULL REFERENCES driver(id),
  season_id_start INT NOT NULL REFERENCES season(id),
  season_id_end INT REFERENCES season(id),
  country_code TEXT NOT NULL REFERENCES countries(country_code),
  PRIMARY KEY(driver_id, season_id_start)
);

CREATE TABLE team_nationality_corrections (
  team_id INT NOT NULL REFERENCES team(id),
  season_id_start INT NOT NULL REFERENCES season(id),
  season_id_end INT REFERENCES season(id),
  country_code TEXT NOT NULL REFERENCES countries(country_code),
  name TEXT,
  PRIMARY KEY(team_id, season_id_start)
);

-- Penalty/staging tables (some FKs uncertain without more context)
CREATE TABLE penalty (
  id INTEGER PRIMARY KEY,
  earned_id INT NOT NULL REFERENCES session_entry(id),
  served_id INT NOT NULL REFERENCES session_entry(id),
  position INT,
  license_points INT,
  is_time_served_in_pit INT DEFAULT 0,
  time TEXT
);