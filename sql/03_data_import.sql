-- ============================================================
-- SUMMER 2026 WORKOUT DATA IMPORT
-- Source: Sum26 sheet from Excel workbook
--
-- Re-runnable: will not duplicate DailySummary dates or the
-- same exercise/value on the same date.
-- ============================================================

USE WorkoutDB;
GO

-- 1. SCHEMA FIXES -----------------------------------------------

-- SleepQuality stored as text (Poor, Ok, Good, Excellent)
ALTER TABLE dbo.DailySummary
ALTER COLUMN SleepQuality VARCHAR(20) NULL;
GO

IF COL_LENGTH('dbo.DailySummary', 'AbsCompleted') IS NULL
BEGIN
    ALTER TABLE dbo.DailySummary
    ADD AbsCompleted CHAR(1) NULL;
END;
GO

IF COL_LENGTH('dbo.DailySummary', 'Notes') IS NULL
BEGIN
    ALTER TABLE dbo.DailySummary
    ADD Notes NVARCHAR(MAX) NULL;
END;
GO

-- Stores the actual logged value from Excel, e.g. 85, EZ @85, LPD@120
IF COL_LENGTH('dbo.Exercises', 'ActualValue') IS NULL
BEGIN
    ALTER TABLE dbo.Exercises
    ADD ActualValue NVARCHAR(100) NULL;
END;
GO

-- 2. STAGE EXERCISE DEFINITIONS ----------------------------------

DROP TABLE IF EXISTS #ExerciseDefinitionData;
GO

CREATE TABLE #ExerciseDefinitionData (
    ExerciseName VARCHAR(100) NOT NULL,
    ExerciseCategory VARCHAR(50) NOT NULL,
    DefaultSets INT NULL,
    DefaultReps INT NULL
);

INSERT INTO #ExerciseDefinitionData (ExerciseName, ExerciseCategory, DefaultSets, DefaultReps)
VALUES
('DB OHP', 'Shoulders', 3, 10),
('DB RAISE', 'Shoulders', 3, 8),
('DB CURL', 'Arms', 2, 10),
('BB BENCH', 'Chest', 3, 12),
('BB ROW', 'Back', 2, 15),
('BB SQUAT', 'Legs', 1, 20),
('BALL YTW', 'Shoulder Mobility', 3, 10),
('DB CALF RAISES', 'Calves', 3, 20),
('DEAD HANG CURLS', 'Grip / Arms', 1, NULL);
GO

-- 3. INSERT EXERCISE DEFINITIONS ----------------------------------

INSERT INTO dbo.ExerciseDefinitions (ExerciseName, ExerciseCategory, DefaultSets, DefaultReps)
SELECT sourceDefs.ExerciseName, sourceDefs.ExerciseCategory, sourceDefs.DefaultSets, sourceDefs.DefaultReps
FROM #ExerciseDefinitionData AS sourceDefs
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.ExerciseDefinitions AS existingDefs
    WHERE existingDefs.ExerciseName = sourceDefs.ExerciseName
);
GO

-- 4. STAGE DAILY SUMMARY DATA --------------------------------------

DROP TABLE IF EXISTS #DailyData;
GO

CREATE TABLE #DailyData (
    WorkoutDate DATE NOT NULL,
    SleepHours DECIMAL(4,2) NULL,
    SleepQuality VARCHAR(20) NULL,
    AbsCompleted CHAR(1) NULL,
    Notes NVARCHAR(MAX) NULL
);

INSERT INTO #DailyData (WorkoutDate, SleepHours, SleepQuality, AbsCompleted, Notes)
VALUES
('2026-05-04', 6,   'Poor',      'Y', N'Knee kind of hurts in the afternoon. Good workout'),
('2026-05-06', 6.5, 'Ok',        'Y', NULL),
('2026-05-11', 7,   'Good',      'N', N'Bench felt soooo good'),
('2026-05-13', 7,   'Good',      'N', NULL),
('2026-05-18', 6,   'Ok',        'N', N'Really attacked arms hard'),
('2026-05-19', 7,   'Good',      'Y', NULL),
('2026-05-21', 7,   'Ok',        NULL, N'Slept wrong, bad neck and shoulder pain'),
('2026-05-26', 6,   'Poor',      NULL, N'Woke up late. Headache. Back from camping'),
('2026-05-27', NULL,NULL,        NULL, N'45min walk @level4 uphill'),
('2026-05-28', 6,   'Ok',        NULL, NULL),
('2026-06-01', 6,   'Ok',        NULL, NULL),
('2026-06-02', 6,   'Ok',        'Y', NULL),
('2026-06-03', 6,   'Ok',        NULL, N'45min walk @level4 uphill'),
('2026-06-04', 7,   'Ok',        NULL, N'Start working out at UHG Optum, BB for Bench seems heavier (Update: BB is still 45, just thicker)'),
('2026-06-05', NULL,NULL,        NULL, N'First day remote work UHC'),
('2026-06-08', 6.5, 'Ok',        NULL, N'Start benching first'),
('2026-06-09', 7,   'Ok',        'Y', NULL),
('2026-06-10', 6,   'Ok',        NULL, NULL),
('2026-06-11', 7,   'Good',      NULL, NULL),
('2026-06-15', 6,   'Poor',      NULL, N'Back to flat BB bench'),
('2026-06-16', 7,   'Poor',      'Y', NULL),
('2026-06-17', 8,   'Excellent', NULL, N'Bike 20min Peleton'),
('2026-06-18', 6,   'Poor',      NULL, N'Upset stomach'),
('2026-06-22', 8,   'Good',      NULL, NULL),
('2026-06-23', 7,   'Good',      'Y', NULL),
('2026-06-24', 7,   'Good',      NULL, N'https://youtu.be/FI51zRzgIe4?is=YeBZ7M_RpG_v7JQg'),
('2026-06-25', 6.5, 'Ok',        NULL, N'Back and legs still very sore from Tuesday');
GO

-- 5. INSERT DAILY SUMMARY DATA -------------------------------------

INSERT INTO dbo.DailySummary ([Date], SleepHours, SleepQuality, WorkoutLocation, AbsCompleted, Notes)
SELECT sourceDays.WorkoutDate, sourceDays.SleepHours, sourceDays.SleepQuality, NULL, sourceDays.AbsCompleted, sourceDays.Notes
FROM #DailyData AS sourceDays
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.DailySummary AS existingDays
    WHERE existingDays.[Date] = sourceDays.WorkoutDate
);
GO

-- 6. STAGE EXERCISE DATA --------------------------------------------

DROP TABLE IF EXISTS #ExerciseData;
GO

CREATE TABLE #ExerciseData (
    WorkoutDate DATE NOT NULL,
    ExerciseName VARCHAR(100) NOT NULL,
    ActualValue NVARCHAR(100) NULL,
    CompletionStatus VARCHAR(20) NULL
);

INSERT INTO #ExerciseData (WorkoutDate, ExerciseName, ActualValue, CompletionStatus)
VALUES
('2026-05-04', 'DB OHP', N'85', 'Pass'),
('2026-05-04', 'DB RAISE', N'15', 'Pass'),
('2026-05-04', 'DB CURL', N'30', 'Pass'),
('2026-05-04', 'BB BENCH', N'140', 'Pass'),
('2026-05-04', 'BB ROW', N'100', 'Pass'),
('2026-05-04', 'BB SQUAT', N'190', 'Pass'),
('2026-05-04', 'BALL YTW', N'0', NULL),
('2026-05-04', 'DB CALF RAISES', N'0', NULL),
('2026-05-04', 'DEAD HANG CURLS', N'0', NULL),
('2026-05-06', 'DB OHP', N'80', 'Pass'),
('2026-05-06', 'DB RAISE', N'10', 'Pass'),
('2026-05-06', 'DB CURL', N'25', 'Pass'),
('2026-05-06', 'BB BENCH', N'135', 'Pass'),
('2026-05-06', 'BB ROW', N'45', 'Pass'),
('2026-05-06', 'BB SQUAT', N'0', NULL),
('2026-05-11', 'DB OHP', N'80', 'Pass'),
('2026-05-11', 'DB RAISE', N'15', 'Pass'),
('2026-05-11', 'DB CURL', N'EZ @85', 'Pass'),
('2026-05-11', 'BB BENCH', N'145', 'Pass'),
('2026-05-11', 'BB ROW', N'95', 'Pass'),
('2026-05-11', 'BB SQUAT', N'200', 'Pass'),
('2026-05-13', 'DB OHP', N'70', 'Pass'),
('2026-05-13', 'DB RAISE', N'15', 'Pass'),
('2026-05-13', 'DB CURL', N'EZ @75', 'Pass'),
('2026-05-13', 'BB BENCH', N'135', 'Pass'),
('2026-05-13', 'BB ROW', N'85', 'Pass'),
('2026-05-13', 'BB SQUAT', N'0', NULL),
('2026-05-18', 'DB OHP', N'85', 'Pass'),
('2026-05-18', 'DB RAISE', N'15', 'Pass'),
('2026-05-18', 'DB CURL', N'EZ @85', 'Pass'),
('2026-05-18', 'BB BENCH', N'145', NULL),
('2026-05-18', 'BB ROW', N'100', NULL),
('2026-05-18', 'BB SQUAT', N'0', NULL),
('2026-05-19', 'BB SQUAT', N'205', 'Fail'),
('2026-05-19', 'BALL YTW', N'2.5', NULL),
('2026-05-19', 'DB CALF RAISES', N'70', NULL),
('2026-05-19', 'DEAD HANG CURLS', N'10', NULL),
('2026-05-21', 'DB OHP', N'85', 'Pass'),
('2026-05-21', 'DB RAISE', N'15', 'Pass'),
('2026-05-21', 'DB CURL', N'30', 'Pass'),
('2026-05-21', 'BB BENCH', N'155', 'Pass'),
('2026-05-21', 'BB ROW', N'105', 'Pass'),
('2026-05-26', 'BB SQUAT', N'205', 'Pass'),
('2026-05-28', 'DB OHP', N'80', 'Pass'),
('2026-05-28', 'DB RAISE', N'15', 'Pass'),
('2026-05-28', 'DB CURL', N'30', 'Pass'),
('2026-05-28', 'BB BENCH', N'145', 'Pass'),
('2026-05-28', 'BB ROW', N'LPD@120', 'Pass'),
('2026-06-01', 'DB OHP', N'80', 'Pass'),
('2026-06-01', 'DB RAISE', N'15', 'Pass'),
('2026-06-01', 'DB CURL', N'30', 'Pass'),
('2026-06-01', 'BB BENCH', N'155', 'Pass'),
('2026-06-01', 'BB ROW', N'95', 'Pass'),
('2026-06-02', 'BB SQUAT', N'210', 'Pass'),
('2026-06-04', 'DB OHP', N'85', 'Pass'),
('2026-06-04', 'DB RAISE', N'15', 'Pass'),
('2026-06-04', 'DB CURL', N'35', 'Pass'),
('2026-06-04', 'BB BENCH', N'145', 'Fail'),
('2026-06-04', 'BB ROW', N'LPD@120', 'Fail'),
('2026-06-08', 'DB OHP', N'85', 'Fail'),
('2026-06-08', 'DB RAISE', N'15', 'Pass'),
('2026-06-08', 'DB CURL', N'35', 'Fail'),
('2026-06-08', 'BB BENCH', N'140', 'Pass'),
('2026-06-08', 'BB ROW', N'100', 'Pass'),
('2026-06-09', 'BB SQUAT', N'210', 'Fail'),
('2026-06-09', 'BALL YTW', N'3', NULL),
('2026-06-09', 'DB CALF RAISES', N'75', NULL),
('2026-06-11', 'BB BENCH', N'150', NULL),
('2026-06-15', 'DB OHP', N'80', 'Fail'),
('2026-06-15', 'DB RAISE', N'15', 'Pass'),
('2026-06-15', 'DB CURL', N'25', 'Pass'),
('2026-06-15', 'BB BENCH', N'155', 'Pass'),
('2026-06-15', 'BB ROW', N'LPD @120', 'Pass'),
('2026-06-16', 'BB SQUAT', N'205', 'Fail'),
('2026-06-18', 'DB OHP', N'75', 'Pass'),
('2026-06-18', 'DB RAISE', N'15', 'Pass'),
('2026-06-18', 'DB CURL', N'30', 'Pass'),
('2026-06-18', 'BB BENCH', N'160', 'Pass'),
('2026-06-22', 'DB OHP', N'80', 'Pass'),
('2026-06-22', 'DB RAISE', N'15', 'Pass'),
('2026-06-22', 'DB CURL', N'30', 'Pass'),
('2026-06-22', 'BB BENCH', N'165', 'Pass'),
('2026-06-22', 'BB ROW', N'95', 'Pass'),
('2026-06-23', 'BB SQUAT', N'205', 'Pass'),
('2026-06-25', 'DB OHP', N'85', 'Pass'),
('2026-06-25', 'DB RAISE', N'20', 'Pass'),
('2026-06-25', 'DB CURL', N'35', 'Pass'),
('2026-06-25', 'BB BENCH', N'170', 'Pass');
GO

-- 7. INSERT EXERCISE DATA --------------------------------------------

INSERT INTO dbo.Exercises (DayID, ExerciseDefID, ExerciseName, ExerciseCategory, Sets, Reps, CompletionStatus, ActualValue)
SELECT
    daily.DayID,
    defs.ExerciseDefID,
    defs.ExerciseName,
    defs.ExerciseCategory,
    defs.DefaultSets,
    defs.DefaultReps,
    stagedExercises.CompletionStatus,
    stagedExercises.ActualValue
FROM #ExerciseData AS stagedExercises
INNER JOIN dbo.DailySummary AS daily ON daily.[Date] = stagedExercises.WorkoutDate
INNER JOIN dbo.ExerciseDefinitions AS defs ON defs.ExerciseName = stagedExercises.ExerciseName
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.Exercises AS existingExercises
    INNER JOIN dbo.DailySummary AS existingDaily ON existingDaily.DayID = existingExercises.DayID
    INNER JOIN dbo.ExerciseDefinitions AS existingDefs ON existingDefs.ExerciseDefID = existingExercises.ExerciseDefID
    WHERE existingDaily.[Date] = stagedExercises.WorkoutDate
      AND existingDefs.ExerciseName = stagedExercises.ExerciseName
      AND ISNULL(existingExercises.ActualValue, N'') = ISNULL(stagedExercises.ActualValue, N'')
);
GO

DROP TABLE IF EXISTS #ExerciseDefinitionData;
DROP TABLE IF EXISTS #DailyData;
DROP TABLE IF EXISTS #ExerciseData;
GO


-- ============================================================
-- STS DATA IMPORT (Gustavus workouts)
-- Source: werner.2025training.xlsx
-- Covers 2025-09-17 through 2026-05-01
-- ============================================================

SET NOCOUNT ON;

-- 1. New definitions for substitute exercises found in the spreadsheet
INSERT INTO ExerciseDefinitions (ExerciseName, ExerciseCategory, DefaultSets, DefaultReps)
SELECT v.ExerciseName, v.ExerciseCategory, v.DefaultSets, v.DefaultReps
FROM (VALUES
    ('CHEST FLY',        'Chest', 3, 12),  -- subbed for BB BENCH
    ('LAT PULL DOWN',    'Back',  2, 15),  -- subbed for BB ROW
    ('TRICEP PULL DOWN', 'Arms',  3, 10)   -- subbed for DB OHP
) AS v(ExerciseName, ExerciseCategory, DefaultSets, DefaultReps)
WHERE NOT EXISTS (
    SELECT 1 FROM ExerciseDefinitions ed WHERE ed.ExerciseName = v.ExerciseName
);
GO

-- 2. Stage daily summary rows. Sleep unknown -> NULL.
--    AbsCompleted = 'Y' only if Plank Circuit column had a value.
IF OBJECT_ID('tempdb..#ImportDays') IS NOT NULL DROP TABLE #ImportDays;
CREATE TABLE #ImportDays (Date DATE, Notes NVARCHAR(500), AbsCompleted CHAR(1));

INSERT INTO #ImportDays (Date, Notes, AbsCompleted) VALUES
    ('2025-09-17', NULL, 'N'),
    ('2025-09-22', NULL, 'N'),
    ('2025-09-26', NULL, 'N'),
    ('2025-09-29', NULL, 'N'),
    ('2025-10-07', NULL, 'N'),
    ('2025-10-10', NULL, 'N'),
    ('2025-10-13', 'Poor sleep / allergies', 'N'),
    ('2025-10-27', 'Using my back on Squats', 'N'),
    ('2025-10-31', NULL, 'N'),
    ('2025-11-03', NULL, 'N'),
    ('2025-11-07', NULL, 'N'),
    ('2025-11-10', NULL, 'N'),
    ('2025-11-13', NULL, 'N'),
    ('2025-11-17', NULL, 'N'),
    ('2025-11-24', NULL, 'N'),
    ('2026-01-12', NULL, 'N'),
    ('2026-01-14', NULL, 'N'),
    ('2026-01-16', NULL, 'N'),
    ('2026-01-23', NULL, 'N'),
    ('2026-01-26', NULL, 'N'),
    ('2026-01-30', NULL, 'N'),
    ('2026-02-02', NULL, 'N'),
    ('2026-02-06', NULL, 'N'),
    ('2026-02-09', NULL, 'N'),
    ('2026-02-13', NULL, 'N'),
    ('2026-02-16', NULL, 'N'),
    ('2026-02-18', NULL, 'N'),
    ('2026-02-20', 'Start incline BB Bench', 'N'),
    ('2026-02-23', NULL, 'N'),
    ('2026-02-25', NULL, 'N'),
    ('2026-02-27', 'Tonsilectomy', 'N'),
    ('2026-03-18', NULL, 'N'),
    ('2026-03-20', 'Flu', 'N'),
    ('2026-03-23', NULL, 'N'),
    ('2026-03-25', NULL, 'N'),
    ('2026-03-27', NULL, 'N'),
    ('2026-03-30', NULL, 'N'),
    ('2026-04-01', NULL, 'N'),
    ('2026-04-06', NULL, 'N'),
    ('2026-04-08', NULL, 'N'),
    ('2026-04-10', 'Workout at apartment', 'N'),
    ('2026-04-13', NULL, 'N'),
    ('2026-04-15', NULL, 'Y'),
    ('2026-04-17', 'Workout at apartment', 'Y'),
    ('2026-04-20', NULL, 'Y'),
    ('2026-04-22', NULL, 'Y'),
    ('2026-04-24', NULL, 'Y'),
    ('2026-04-27', 'Last day of classes at GAC', 'Y'),
    ('2026-04-29', NULL, 'N'),
    ('2026-05-01', NULL, 'N');

-- 3. Insert into DailySummary (skips dates that already exist)
INSERT INTO DailySummary (Date, SleepHours, SleepQuality, WorkoutLocation, AbsCompleted, Notes)
SELECT id.Date, NULL, NULL, 'Gustavus', id.AbsCompleted, id.Notes
FROM #ImportDays id
WHERE NOT EXISTS (
    SELECT 1 FROM DailySummary ds WHERE ds.Date = id.Date
);

-- 4. Stage every logged exercise value (defaults come from ExerciseDefinitions)
IF OBJECT_ID('tempdb..#ImportExercises') IS NOT NULL DROP TABLE #ImportExercises;
CREATE TABLE #ImportExercises (Date DATE, ExerciseName NVARCHAR(100), ActualValue DECIMAL(10,2));

INSERT INTO #ImportExercises (Date, ExerciseName, ActualValue) VALUES
    ('2025-09-17', 'DB OHP', 40),
    ('2025-09-17', 'BB BENCH', 115),
    ('2025-09-17', 'BB ROW', 65),
    ('2025-09-17', 'DB CURL', 20),
    ('2025-09-17', 'BB SQUAT', 135),
    ('2025-09-17', 'BALL YTW', 0),
    ('2025-09-17', 'DB CALF RAISES', 50),
    ('2025-09-17', 'DEAD HANG CURLS', 10),
    ('2025-09-22', 'DB OHP', 45),
    ('2025-09-22', 'BB BENCH', 125),
    ('2025-09-22', 'BB ROW', 70),
    ('2025-09-22', 'DB CURL', 20),
    ('2025-09-22', 'BB SQUAT', 135),
    ('2025-09-22', 'BALL YTW', 0),
    ('2025-09-22', 'DB CALF RAISES', 60),
    ('2025-09-22', 'DEAD HANG CURLS', 10),
    ('2025-09-26', 'DB OHP', 50),
    ('2025-09-26', 'BB BENCH', 130),
    ('2025-09-26', 'BB ROW', 75),
    ('2025-09-26', 'DB CURL', 25),
    ('2025-09-26', 'BB SQUAT', 145),
    ('2025-09-26', 'BALL YTW', 0),
    ('2025-09-26', 'DB CALF RAISES', 65),
    ('2025-09-26', 'DEAD HANG CURLS', 15),
    ('2025-09-29', 'DB OHP', 55),
    ('2025-09-29', 'BB BENCH', 135),
    ('2025-09-29', 'BB ROW', 80),
    ('2025-09-29', 'DB CURL', 25),
    ('2025-09-29', 'BB SQUAT', 165),
    ('2025-10-07', 'DB OHP', 60),
    ('2025-10-07', 'BB BENCH', 145),
    ('2025-10-07', 'BB ROW', 85),
    ('2025-10-07', 'DB CURL', 30),
    ('2025-10-07', 'BB SQUAT', 175),
    ('2025-10-10', 'DB OHP', 65),
    ('2025-10-10', 'BB BENCH', 150),
    ('2025-10-10', 'BB ROW', 85),
    ('2025-10-10', 'DB CURL', 30),
    ('2025-10-13', 'DB OHP', 65),
    ('2025-10-13', 'BB BENCH', 155),
    ('2025-10-13', 'BB ROW', 85),
    ('2025-10-13', 'DB CURL', 35),
    ('2025-10-13', 'BB SQUAT', 185),
    ('2025-10-27', 'DB OHP', 65),
    ('2025-10-27', 'BB BENCH', 135),
    ('2025-10-27', 'BB ROW', 90),
    ('2025-10-27', 'DB CURL', 30),
    ('2025-10-27', 'BB SQUAT', 185),
    ('2025-10-31', 'DB OHP', 60),
    ('2025-10-31', 'BB BENCH', 145),
    ('2025-10-31', 'BB ROW', 95),
    ('2025-10-31', 'DB CURL', 30),
    ('2025-10-31', 'BB SQUAT', 185),
    ('2025-11-03', 'DB OHP', 65),
    ('2025-11-03', 'BB BENCH', 145),
    ('2025-11-03', 'BB ROW', 105),
    ('2025-11-03', 'DB CURL', 35),
    ('2025-11-03', 'BB SQUAT', 195),
    ('2025-11-07', 'DB OHP', 65),
    ('2025-11-07', 'BB BENCH', 135),
    ('2025-11-07', 'BB ROW', 95),
    ('2025-11-07', 'DB CURL', 35),
    ('2025-11-10', 'DB OHP', 70),
    ('2025-11-10', 'BB BENCH', 135),
    ('2025-11-10', 'BB ROW', 95),
    ('2025-11-10', 'DB CURL', 32.5),
    ('2025-11-10', 'BB SQUAT', 185),
    ('2025-11-13', 'DB OHP', 70),
    ('2025-11-13', 'BB BENCH', 135),
    ('2025-11-13', 'BB ROW', 95),
    ('2025-11-13', 'DB CURL', 30),
    ('2025-11-13', 'BB SQUAT', 0),
    ('2025-11-17', 'DB OHP', 70),
    ('2025-11-17', 'BB BENCH', 145),
    ('2025-11-17', 'BB ROW', 95),
    ('2025-11-17', 'DB CURL', 30),
    ('2025-11-17', 'BB SQUAT', 185),
    ('2025-11-24', 'DB OHP', 70),
    ('2025-11-24', 'DB CURL', 30),
    ('2026-01-12', 'DB OHP', 60),
    ('2026-01-12', 'BB BENCH', 105),
    ('2026-01-12', 'BB ROW', 85),
    ('2026-01-12', 'DB CURL', 20),
    ('2026-01-14', 'DB OHP', 40),
    ('2026-01-14', 'DB CURL', 15),
    ('2026-01-16', 'DB OHP', 65),
    ('2026-01-16', 'BB BENCH', 115),
    ('2026-01-16', 'BB ROW', 90),
    ('2026-01-16', 'DB CURL', 25),
    ('2026-01-23', 'DB OHP', 65),
    ('2026-01-23', 'BB BENCH', 135),
    ('2026-01-23', 'BB ROW', 85),
    ('2026-01-23', 'DB CURL', 25),
    ('2026-01-23', 'DB CALF RAISES', 65),
    ('2026-01-23', 'DEAD HANG CURLS', 10),
    ('2026-01-26', 'DB OHP', 70),
    ('2026-01-26', 'BB BENCH', 140),
    ('2026-01-26', 'BB ROW', 85),
    ('2026-01-26', 'DB CURL', 25),
    ('2026-01-26', 'DB CALF RAISES', 65),
    ('2026-01-26', 'DEAD HANG CURLS', 10),
    ('2026-01-30', 'DB OHP', 70),
    ('2026-01-30', 'CHEST FLY', 22.0),
    ('2026-01-30', 'LAT PULL DOWN', 99.0),
    ('2026-01-30', 'DB CURL', 20),
    ('2026-01-30', 'DB CALF RAISES', 0),
    ('2026-01-30', 'DEAD HANG CURLS', 10),
    ('2026-02-02', 'DB OHP', 70),
    ('2026-02-02', 'BB BENCH', 145),
    ('2026-02-02', 'BB ROW', 95),
    ('2026-02-02', 'DB CURL', 20),
    ('2026-02-02', 'BB SQUAT', 175),
    ('2026-02-02', 'DB CALF RAISES', 0),
    ('2026-02-02', 'DEAD HANG CURLS', 10),
    ('2026-02-06', 'DB OHP', 70),
    ('2026-02-06', 'BB BENCH', 145),
    ('2026-02-06', 'BB ROW', 95),
    ('2026-02-06', 'DB CURL', 20),
    ('2026-02-06', 'DB CALF RAISES', 0),
    ('2026-02-06', 'DEAD HANG CURLS', 10),
    ('2026-02-09', 'DB OHP', 75),
    ('2026-02-09', 'BB BENCH', 135),
    ('2026-02-09', 'BB ROW', 95),
    ('2026-02-09', 'DB CURL', 25),
    ('2026-02-09', 'BB SQUAT', 185),
    ('2026-02-09', 'DB CALF RAISES', 0),
    ('2026-02-09', 'DEAD HANG CURLS', 10),
    ('2026-02-13', 'DB OHP', 75),
    ('2026-02-13', 'CHEST FLY', 27.5),
    ('2026-02-13', 'LAT PULL DOWN', 110.0),
    ('2026-02-13', 'DB CURL', 25),
    ('2026-02-13', 'BB SQUAT', 190),
    ('2026-02-13', 'DB CALF RAISES', 0),
    ('2026-02-13', 'DEAD HANG CURLS', 15),
    ('2026-02-16', 'DB OHP', 80),
    ('2026-02-16', 'BB BENCH', 145),
    ('2026-02-16', 'BB ROW', 95),
    ('2026-02-16', 'DB CURL', 30),
    ('2026-02-16', 'BB SQUAT', 195),
    ('2026-02-16', 'DB CALF RAISES', 0),
    ('2026-02-16', 'DEAD HANG CURLS', 15),
    ('2026-02-18', 'DB OHP', 80),
    ('2026-02-18', 'BB BENCH', 95),
    ('2026-02-18', 'LAT PULL DOWN', 121.0),
    ('2026-02-18', 'DB CURL', 30),
    ('2026-02-18', 'DB CALF RAISES', 0),
    ('2026-02-18', 'DEAD HANG CURLS', 15),
    ('2026-02-20', 'DB OHP', 75),
    ('2026-02-20', 'BB BENCH', 135),
    ('2026-02-20', 'DB CURL', 30),
    ('2026-02-23', 'DB OHP', 75),
    ('2026-02-23', 'BB BENCH', 145),
    ('2026-02-23', 'BB ROW', 95),
    ('2026-02-23', 'DB CURL', 30),
    ('2026-02-23', 'BB SQUAT', 205),
    ('2026-02-25', 'TRICEP PULL DOWN', 10.0),
    ('2026-02-25', 'CHEST FLY', 120.0),
    ('2026-02-25', 'LAT PULL DOWN', 110.0),
    ('2026-03-18', 'DB OHP', 45),
    ('2026-03-18', 'BB BENCH', 95),
    ('2026-03-18', 'LAT PULL DOWN', 90.0),
    ('2026-03-18', 'DB CURL', 20),
    ('2026-03-23', 'DB OHP', 70),
    ('2026-03-23', 'BB BENCH', 125),
    ('2026-03-23', 'BB ROW', 85),
    ('2026-03-23', 'DB CURL', 30),
    ('2026-03-25', 'DB OHP', 60),
    ('2026-03-25', 'CHEST FLY', 100.0),
    ('2026-03-25', 'DB CURL', 25),
    ('2026-03-27', 'DB OHP', 70),
    ('2026-03-27', 'BB BENCH', 135),
    ('2026-03-27', 'LAT PULL DOWN', 110.0),
    ('2026-03-27', 'DB CURL', 25),
    ('2026-03-30', 'DB OHP', 75),
    ('2026-03-30', 'BB BENCH', 145),
    ('2026-03-30', 'DB CURL', 25),
    ('2026-04-01', 'DB OHP', 75),
    ('2026-04-01', 'CHEST FLY', 110.0),
    ('2026-04-01', 'LAT PULL DOWN', 110.0),
    ('2026-04-01', 'DB CURL', 25),
    ('2026-04-06', 'DB OHP', 80),
    ('2026-04-06', 'BB BENCH', 145),
    ('2026-04-06', 'BB ROW', 95),
    ('2026-04-06', 'DB CURL', 30),
    ('2026-04-06', 'BB SQUAT', 185),
    ('2026-04-08', 'DB OHP', 75),
    ('2026-04-08', 'CHEST FLY', 120.0),
    ('2026-04-08', 'LAT PULL DOWN', 110.0),
    ('2026-04-08', 'DB CURL', 25),
    ('2026-04-13', 'DB OHP', 80),
    ('2026-04-13', 'BB BENCH', 155),
    ('2026-04-13', 'BB ROW', 95),
    ('2026-04-13', 'DB CURL', 30),
    ('2026-04-13', 'BB SQUAT', 185),
    ('2026-04-15', 'DB OHP', 80),
    ('2026-04-15', 'BB BENCH', 145),
    ('2026-04-15', 'BB ROW', 95),
    ('2026-04-15', 'DB CURL', 30),
    ('2026-04-17', 'TRICEP PULL DOWN', 40.0),
    ('2026-04-17', 'DB CURL', 25),
    ('2026-04-20', 'DB OHP', 80),
    ('2026-04-20', 'BB BENCH', 145),
    ('2026-04-20', 'BB ROW', 100),
    ('2026-04-20', 'DB CURL', 30),
    ('2026-04-20', 'BB SQUAT', 185),
    ('2026-04-22', 'DB OHP', 70),
    ('2026-04-22', 'CHEST FLY', 130.0),
    ('2026-04-22', 'LAT PULL DOWN', 121.0),
    ('2026-04-22', 'DB CURL', 25),
    ('2026-04-24', 'DB OHP', 85),
    ('2026-04-24', 'BB BENCH', 145),
    ('2026-04-24', 'BB ROW', 100),
    ('2026-04-24', 'DB CURL', 30),
    ('2026-04-27', 'DB OHP', 80),
    ('2026-04-27', 'BB ROW', 105),
    ('2026-04-27', 'DB CURL', 35),
    ('2026-04-27', 'BB SQUAT', 185),
    ('2026-04-29', 'DB OHP', 75),
    ('2026-04-29', 'BB BENCH', 135),
    ('2026-04-29', 'BB ROW', 95),
    ('2026-04-29', 'DB CURL', 30),
    ('2026-05-01', 'DB OHP', 85),
    ('2026-05-01', 'BB BENCH', 145),
    ('2026-05-01', 'BB ROW', 105),
    ('2026-05-01', 'DB CURL', 35);

-- 5. Insert into Exercises, joined to new DailySummary rows and ExerciseDefinitions
INSERT INTO Exercises (DayID, ExerciseName, ExerciseCategory, Sets, Reps, CompletionStatus, ExerciseDefID, ActualValue, ActualSets, ActualReps)
SELECT ds.DayID, ed.ExerciseName, ed.ExerciseCategory, ed.DefaultSets, ed.DefaultReps,
       'Pass', ed.ExerciseDefID, ie.ActualValue, ed.DefaultSets, ed.DefaultReps
FROM #ImportExercises ie
JOIN DailySummary ds ON ds.Date = ie.Date AND ds.WorkoutLocation = 'Gustavus'
JOIN ExerciseDefinitions ed ON ed.ExerciseName = ie.ExerciseName
WHERE NOT EXISTS (
    SELECT 1 FROM Exercises ex
    WHERE ex.DayID = ds.DayID AND ex.ExerciseDefID = ed.ExerciseDefID
);

DROP TABLE #ImportDays;
DROP TABLE #ImportExercises;
