-- ============================================================
-- Table Setup
-- ============================================================

CREATE TABLE DailySummary (
    DayID INT IDENTITY(1,1) PRIMARY KEY,
    Date DATE NOT NULL,
    SleepHours DECIMAL(4,2),
    SleepQuality INT,
    WorkoutLocation VARCHAR(50)
);

-- Add columns to track actual (vs. planned) sets/reps per exercise
ALTER TABLE dbo.Exercises
ADD ActualSets INT NULL,
    ActualReps INT NULL;
