CREATE TABLE base_team(id INT,name TEXT);
CREATE TABLE championship_adjustment(
  id INT,
  adjustment INT,
  driver_id INT,
  points REAL,
  season_id INT,
  team_id INT
);
CREATE TABLE championship_system(
  id INT,
  name TEXT,
  reference TEXT,
  driver_best_results INT,
  team_best_results INT,
  driver_season_split INT,
  team_season_split INT,
  team_points_per_session INT,
  eligibility TEXT
);
CREATE TABLE circuit(
  id INT,
  name TEXT,
  reference TEXT,
  locality TEXT,
  country TEXT,
  country_code TEXT,
  latitude REAL,
  longitude REAL,
  altitude INT,
  wikipedia TEXT
);
CREATE TABLE countries(
  id,
  country_code TEXT,
  country TEXT
);
CREATE TABLE driver(
  id INT,
  reference TEXT,
  abbreviation TEXT,
  forename TEXT,
  surname TEXT,
  country_code TEXT,
  date_of_birth,
  permanent_car_number INT,
  wikipedia TEXT
);
CREATE TABLE driver_championship(
  id INT,
  season_id INT,
  year INT,
  driver_id INT,
  round_id INT,
  position INT,
  points REAL,
  win_count INT,
  highest_finish INT,
  is_eligible INT,
  adjustment_type TEXT,
  session_id INT,
  session_number INT,
  round_number INT
);
CREATE TABLE "driver_nationality_corrections" (driver_id INT,season_id_start INT,season_id_end INT,country_code TEXT);
CREATE TABLE lap(
  id INT,
  session_entry_id INT,
  number INT,
  position INT,
  time TEXT,
  average_speed TEXT,
  is_entry_fastest_lap INT,
  is_deleted INT
);
CREATE TABLE penalty(
  id INT,
  earned_id INT,
  served_id INT,
  position INT,
  license_points INT,
  is_time_served_in_pit INT,
  time TEXT
);
CREATE TABLE pit_stop(
  id INT,
  session_entry_id INT,
  lap_id INT,
  number INT,
  duration TEXT,
  local_timestamp TEXT
);
CREATE TABLE points_system(
  id INT,
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
CREATE TABLE round(
  id INT,
  season_id INT,
  circuit_id INT,
  number INT,
  race_number INT,
  name TEXT,
  date,
  is_cancelled INT,
  wikipedia TEXT
);
CREATE TABLE roundentry(
  id INT,
  round_id INT,
  team_driver_id INT,
  car_number INT
);
CREATE TABLE season(
  id INT,
  year INT,
  championship_system_id INT,
  wikipedia TEXT
);
CREATE TABLE season_driver(
  id,
  season_id INT,
  driver_id INT,
  country_id
);
CREATE TABLE season_team(
  id,
  season_id INT,
  team_id INT,
  country_id,
  name
);
CREATE TABLE session(
  id INT,
  round_id INT,
  type TEXT,
  number INT,
  timestamp,
  timezone TEXT,
  scheduled_laps INT,
  point_system_id INT,
  is_cancelled INT,
  has_time_data INT
);
CREATE TABLE session_entry(
  id INT,
  session_id INT,
  round_entry_id INT,
  grid INT,
  position INT,
  points REAL,
  laps_completed INT,
  fastest_lap_rank INT,
  time TEXT,
  detail TEXT,
  status TEXT,
  is_classified INT,
  is_eligible_for_points INT
);
CREATE TABLE team(
  id INT,
  name TEXT,
  reference TEXT,
  country_code TEXT,
  base_team_id INT,
  primary_color TEXT,
  wikipedia TEXT
);
CREATE TABLE team_championship(
  id INT,
  season_id INT,
  year INT,
  team_id INT,
  round_id INT,
  position INT,
  points REAL,
  win_count INT,
  highest_finish INT,
  is_eligible INT,
  adjustment_type TEXT,
  session_id INT,
  session_number INT,
  round_number INT
);
CREATE TABLE team_driver(
  id INT,
  season_id INT,
  team_id INT,
  driver_id INT,
  role TEXT
);
CREATE TABLE "team_nationality_corrections" (team_id INT,season_id_start INT,season_id_end INT,country_code TEXT,name TEXT);
