-- ============================================================
-- Data Cleaning: DailySummary
-- ============================================================

UPDATE DailySummary
SET WorkoutLocation = 'Optum'
WHERE WorkoutLocation IS NULL;

UPDATE DailySummary
SET SleepQuality = 'Good'
WHERE SleepQuality = '8';

UPDATE DailySummary
SET AbsCompleted = 'N'
WHERE AbsCompleted IS NULL;


-- ============================================================
-- Data Cleaning: ExerciseDefinitions
-- ============================================================

BEGIN TRANSACTION;

-- Remove unused duplicate definitions
DELETE FROM ExerciseDefinitions
WHERE ExerciseDefID IN (1, 2, 4, 5);

-- Capitalize BB Squat
UPDATE ExerciseDefinitions
SET ExerciseName = 'BB SQUAT'
WHERE ExerciseDefID = 3;

-- Update categories
UPDATE ExerciseDefinitions SET ExerciseCategory = 'Arms' WHERE ExerciseName = 'DB OHP';
UPDATE ExerciseDefinitions SET ExerciseCategory = 'Back' WHERE ExerciseName = 'BALL YTW';
UPDATE ExerciseDefinitions SET ExerciseCategory = 'Legs' WHERE ExerciseName = 'DB CALF RAISES';
UPDATE ExerciseDefinitions SET ExerciseCategory = 'Core' WHERE ExerciseName = 'DEAD HANG CURLS';

-- COMMIT; or ROLLBACK;


-- ============================================================
-- Data Cleaning: Exercises
-- ============================================================

-- Backfill ActualSets/ActualReps from planned Sets/Reps
UPDATE Exercises
SET ActualSets = Sets
WHERE ActualSets IS NULL;

UPDATE Exercises
SET ActualReps = Reps
WHERE ActualReps IS NULL;

-- Set NULL Reps to 1 (run before ActualReps backfill if NULL reps should become 1)
UPDATE Exercises
SET Reps = 1
WHERE Reps IS NULL;

-- Set NULL CompletionStatus to 'Pass'
UPDATE Exercises
SET CompletionStatus = 'Pass'
WHERE CompletionStatus IS NULL;

BEGIN TRANSACTION;

-- EZ @ values -> strip to numeric, rename exercise
UPDATE Exercises
SET ActualValue = LTRIM(RTRIM(SUBSTRING(ActualValue, CHARINDEX('@', ActualValue) + 1, LEN(ActualValue)))),
    ExerciseName = 'EZ Curl'
WHERE ActualValue LIKE 'EZ @%';

-- LPD @ values -> strip to numeric, rename exercise (handles 'LPD@' and 'LPD @')
UPDATE Exercises
SET ActualValue = LTRIM(RTRIM(SUBSTRING(ActualValue, CHARINDEX('@', ActualValue) + 1, LEN(ActualValue)))),
    ExerciseName = 'Lat Pull Down'
WHERE ActualValue LIKE 'LPD%@%';

COMMIT;

-- Uppercase all exercise names
UPDATE Exercises
SET ExerciseName = UPPER(ExerciseName);
