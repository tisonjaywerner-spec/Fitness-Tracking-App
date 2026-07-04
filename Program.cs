using Microsoft.Data.SqlClient;
using System.Text.Json;

var builder = WebApplication.CreateBuilder(args);

var app = builder.Build();

string connectionString = builder.Configuration.GetConnectionString("WorkoutDB");

// ---------------------------------------------------------------------
// EXISTING DATA ENTRY FORM (unchanged from your current app)
// ---------------------------------------------------------------------
app.MapGet("/", async (HttpRequest request) =>
{
    var exercises = new List<(string Name, int? Sets, int? Reps)>();

    using (var conn = new SqlConnection(connectionString))
    {
        await conn.OpenAsync();

        var cmd = new SqlCommand(
            "SELECT ExerciseName, DefaultSets, DefaultReps FROM dbo.ExerciseDefinitions ORDER BY ExerciseName",
            conn
        );

        using var reader = await cmd.ExecuteReaderAsync();

        while (await reader.ReadAsync())
        {
            exercises.Add((
                reader.GetString(0),
                reader.IsDBNull(1) ? null : reader.GetInt32(1),
                reader.IsDBNull(2) ? null : reader.GetInt32(2)
            ));
        }
    }

    string options = string.Join("", exercises.Select(e =>
        $"<option value='{System.Net.WebUtility.HtmlEncode(e.Name)}'>{System.Net.WebUtility.HtmlEncode(e.Name)}</option>"
    ));

    var exerciseLookup = exercises.ToDictionary(e => e.Name, e => new { sets = e.Sets, reps = e.Reps });
    string exerciseLookupJson = JsonSerializer.Serialize(exerciseLookup);

    string today = DateTime.Now.ToString("yyyy-MM-dd");

    string status = request.Query["status"].ToString();
    string banner = status switch
    {
        "ok" => "<div class='banner ok'>Saved successfully.</div>",
        "ok_dupes" => "<div class='banner warn'>Saved, but some exercises were skipped as duplicates for that date.</div>",
        "notfound" => "<div class='banner err'>One or more exercises weren't found in ExerciseDefinitions — nothing was saved.</div>",
        "error" => "<div class='banner err'>Something went wrong saving your entry. Please try again.</div>",
        _ => ""
    };

    return Results.Content($$"""
    <!DOCTYPE html>
    <html>
    <head>
        <title>Tison's Workout Tracker</title>
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <style>
            body {
                font-family: Arial;
                padding: 16px;
                max-width: 420px;
                margin: auto;
                background: #CCCCCC;
            }
            input, select, textarea, button {
                width: 100%;
                padding: 12px;
                margin: 8px 0;
                font-size: 16px;
                box-sizing: border-box;
            }
            button {
                background: #008000;
                color: white;
                border: none;
                border-radius: 6px;
            }
            button.secondary {
                background: #555;
            }
            button.remove {
                background: #b00020;
                width: auto;
                padding: 6px 12px;
                font-size: 13px;
                margin: 0;
            }
            .box {
                background: white;
                padding: 14px;
                border-radius: 8px;
                margin-bottom: 14px;
                position: relative;
            }
            .checkbox-row {
                display: flex;
                align-items: center;
                gap: 8px;
            }
            .checkbox-row input {
                width: auto;
            }
            .planned {
                font-size: 13px;
                color: #555;
                margin: -4px 0 8px 0;
            }
            .row {
                display: flex;
                gap: 8px;
            }
            .row > div {
                flex: 1;
            }
            .exercise-header {
                display: flex;
                justify-content: space-between;
                align-items: center;
            }
            .banner {
                padding: 12px;
                border-radius: 6px;
                margin-bottom: 12px;
                font-weight: bold;
                text-align: center;
            }
            .banner.ok { background: #d4edda; color: #155724; }
            .banner.warn { background: #fff3cd; color: #856404; }
            .banner.err { background: #f8d7da; color: #721c24; }
            .navlink {
                display: block;
                text-align: center;
                background: #1a3d33;
                color: white;
                padding: 10px;
                border-radius: 6px;
                text-decoration: none;
                margin-bottom: 14px;
                font-weight: bold;
            }
        </style>
    </head>
    <body>
        <h2>Tison's Workout Tracker</h2>

        <a class="navlink" href="/dashboard">View Dashboards</a>

        {{banner}}

        <form method="post" action="/save" id="workoutForm">
            <div class="box">
                <h3>Day Info</h3>

                <label>Date</label>
                <input type="date" name="WorkoutDate" value="{{today}}" required />

                <label>Sleep Hours</label>
                <input type="number" step="0.25" name="SleepHours" />

                <label>Sleep Quality</label>
                <select name="SleepQuality">
                    <option value=""></option>
                    <option>Poor</option>
                    <option>Ok</option>
                    <option>Good</option>
                    <option>Excellent</option>
                </select>

                <label>Workout Location</label>
                <select name="WorkoutLocation">
                    <option value=""></option>
                    <option>Optum</option>
                    <option>UHC</option>
                    <option>Gustavus</option>
                    <option>Stronghold</option>
                    <option>Other</option>
                </select>

                <div class="checkbox-row">
                    <input type="checkbox" name="AbsCompleted" value="Y" id="abs" />
                    <label for="abs">Abs Completed</label>
                </div>

                <label>Notes</label>
                <textarea name="Notes"></textarea>
            </div>

            <div id="exerciseContainer"></div>

            <button type="button" class="secondary" onclick="addExercise()">+ Add Another Exercise</button>
            <input type="hidden" name="ExerciseCount" id="exerciseCount" value="0" />

            <button type="submit">Save Workout Entry</button>
        </form>

        <script>
            const exerciseData = {{exerciseLookupJson}};
            const exerciseOptions = `{{options}}`;
            let exerciseIndex = 0;

            function addExercise() {
                exerciseIndex++;
                const container = document.getElementById('exerciseContainer');

                const block = document.createElement('div');
                block.className = 'box';
                block.id = 'exercise_' + exerciseIndex;
                block.innerHTML = `
                    <div class="exercise-header">
                        <h3>Exercise</h3>
                        ${exerciseIndex > 1 ? `<button type="button" class="remove" onclick="removeExercise(${exerciseIndex})">Remove</button>` : ''}
                    </div>

                    <label>Exercise</label>
                    <select name="ExerciseName_${exerciseIndex}" required onchange="updatePlanned(${exerciseIndex})">
                        <option value=""></option>
                        ${exerciseOptions}
                    </select>
                    <div class="planned" id="planned_${exerciseIndex}"></div>

                    <div class="row">
                        <div>
                            <label>Actual Sets</label>
                            <input type="number" name="ActualSets_${exerciseIndex}" id="sets_${exerciseIndex}" />
                        </div>
                        <div>
                            <label>Actual Reps</label>
                            <input type="number" name="ActualReps_${exerciseIndex}" id="reps_${exerciseIndex}" />
                        </div>
                    </div>

                    <label>Actual Weight / Value</label>
                    <input type="text" name="ActualValue_${exerciseIndex}" placeholder="Example: 85" required />

                    <label>Status</label>
                    <select name="CompletionStatus_${exerciseIndex}">
                        <option value=""></option>
                        <option>Pass</option>
                        <option>Fail</option>
                    </select>
                `;
                container.appendChild(block);
                document.getElementById('exerciseCount').value = exerciseIndex;
            }

            function removeExercise(index) {
                const block = document.getElementById('exercise_' + index);
                if (block) block.remove();
            }

            function updatePlanned(index) {
                const select = document.querySelector(`select[name="ExerciseName_${index}"]`);
                const info = exerciseData[select.value];
                const plannedDiv = document.getElementById('planned_' + index);
                const setsInput = document.getElementById('sets_' + index);
                const repsInput = document.getElementById('reps_' + index);

                if (info) {
                    plannedDiv.textContent = `Planned: ${info.sets ?? '-'} sets x ${info.reps ?? '-'} reps`;
                    if (!setsInput.value) setsInput.value = info.sets ?? '';
                    if (!repsInput.value) repsInput.value = info.reps ?? '';
                } else {
                    plannedDiv.textContent = '';
                }
            }

            addExercise();
        </script>
    </body>
    </html>
    """, "text/html");
});

app.MapPost("/save", async (HttpRequest request) =>
{
    var form = await request.ReadFormAsync();

    var workoutDate = form["WorkoutDate"].ToString();
    var sleepHours = form["SleepHours"].ToString();
    var sleepQuality = form["SleepQuality"].ToString();
    var workoutLocation = form["WorkoutLocation"].ToString();
    var absCompleted = form["AbsCompleted"].ToString();
    var notes = form["Notes"].ToString();

    decimal? sleepHoursValue = null;
    if (!string.IsNullOrWhiteSpace(sleepHours) && decimal.TryParse(sleepHours, out var parsedSleep))
    {
        sleepHoursValue = parsedSleep;
    }

    int exerciseCount = int.TryParse(form["ExerciseCount"].ToString(), out var c) ? c : 0;

    var exerciseRows = new List<(string Name, string ActualValue, string Status, int? ActualSets, int? ActualReps)>();

    for (int i = 1; i <= exerciseCount; i++)
    {
        var name = form[$"ExerciseName_{i}"].ToString();
        if (string.IsNullOrWhiteSpace(name)) continue;

        var actualValue = form[$"ActualValue_{i}"].ToString();
        var status = form[$"CompletionStatus_{i}"].ToString();
        int? actualSets = int.TryParse(form[$"ActualSets_{i}"].ToString(), out var s) ? s : null;
        int? actualReps = int.TryParse(form[$"ActualReps_{i}"].ToString(), out var r) ? r : null;

        exerciseRows.Add((name, actualValue, status, actualSets, actualReps));
    }

    if (exerciseRows.Count == 0)
    {
        return Results.Redirect("/?status=error");
    }

    try
    {
        using var conn = new SqlConnection(connectionString);
        await conn.OpenAsync();

        foreach (var row in exerciseRows)
        {
            using var checkCmd = new SqlCommand(
                "SELECT COUNT(1) FROM dbo.ExerciseDefinitions WHERE ExerciseName = @ExerciseName", conn);
            checkCmd.Parameters.AddWithValue("@ExerciseName", row.Name);
            var exists = (int)(await checkCmd.ExecuteScalarAsync() ?? 0);

            if (exists == 0)
            {
                return Results.Redirect("/?status=notfound");
            }
        }

        int dayId;
        using (var daySql = new SqlCommand("""
            IF NOT EXISTS (SELECT 1 FROM dbo.DailySummary WHERE [Date] = @WorkoutDate)
            BEGIN
                INSERT INTO dbo.DailySummary
                    ([Date], SleepHours, SleepQuality, WorkoutLocation, AbsCompleted, Notes)
                VALUES
                    (@WorkoutDate, @SleepHours, @SleepQuality, @WorkoutLocation, @AbsCompleted, @Notes);
            END
            ELSE
            BEGIN
                UPDATE dbo.DailySummary
                SET
                    SleepHours = COALESCE(@SleepHours, SleepHours),
                    SleepQuality = COALESCE(@SleepQuality, SleepQuality),
                    WorkoutLocation = COALESCE(@WorkoutLocation, WorkoutLocation),
                    AbsCompleted = COALESCE(@AbsCompleted, AbsCompleted),
                    Notes = COALESCE(@Notes, Notes)
                WHERE [Date] = @WorkoutDate;
            END

            SELECT DayID FROM dbo.DailySummary WHERE [Date] = @WorkoutDate;
            """, conn))
        {
            daySql.Parameters.AddWithValue("@WorkoutDate", workoutDate);
            daySql.Parameters.AddWithValue("@SleepHours", (object?)sleepHoursValue ?? DBNull.Value);
            daySql.Parameters.AddWithValue("@SleepQuality", string.IsNullOrWhiteSpace(sleepQuality) ? DBNull.Value : sleepQuality);
            daySql.Parameters.AddWithValue("@WorkoutLocation", string.IsNullOrWhiteSpace(workoutLocation) ? DBNull.Value : workoutLocation);
            daySql.Parameters.AddWithValue("@AbsCompleted", string.IsNullOrWhiteSpace(absCompleted) ? "N" : "Y");
            daySql.Parameters.AddWithValue("@Notes", string.IsNullOrWhiteSpace(notes) ? DBNull.Value : notes);

            dayId = (int)(await daySql.ExecuteScalarAsync() ?? 0);
        }

        int skippedDuplicates = 0;

        foreach (var row in exerciseRows)
        {
            using (var dupCheck = new SqlCommand(
                "SELECT COUNT(1) FROM dbo.Exercises WHERE DayID = @DayID AND ExerciseName = @ExerciseName", conn))
            {
                dupCheck.Parameters.AddWithValue("@DayID", dayId);
                dupCheck.Parameters.AddWithValue("@ExerciseName", row.Name);
                var dupExists = (int)(await dupCheck.ExecuteScalarAsync() ?? 0);

                if (dupExists > 0)
                {
                    skippedDuplicates++;
                    continue;
                }
            }

            using var insertCmd = new SqlCommand("""
                INSERT INTO dbo.Exercises
                    (DayID, ExerciseDefID, ExerciseName, ExerciseCategory, Sets, Reps, ActualSets, ActualReps, CompletionStatus, ActualValue)
                SELECT
                    @DayID,
                    ExerciseDefID,
                    ExerciseName,
                    ExerciseCategory,
                    DefaultSets,
                    DefaultReps,
                    @ActualSets,
                    @ActualReps,
                    @CompletionStatus,
                    @ActualValue
                FROM dbo.ExerciseDefinitions
                WHERE ExerciseName = @ExerciseName;
                """, conn);

            insertCmd.Parameters.AddWithValue("@DayID", dayId);
            insertCmd.Parameters.AddWithValue("@ActualSets", (object?)row.ActualSets ?? DBNull.Value);
            insertCmd.Parameters.AddWithValue("@ActualReps", (object?)row.ActualReps ?? DBNull.Value);
            insertCmd.Parameters.AddWithValue("@CompletionStatus", string.IsNullOrWhiteSpace(row.Status) ? DBNull.Value : row.Status);
            insertCmd.Parameters.AddWithValue("@ActualValue", row.ActualValue);
            insertCmd.Parameters.AddWithValue("@ExerciseName", row.Name);

            await insertCmd.ExecuteNonQueryAsync();
        }

        return Results.Redirect(skippedDuplicates > 0 ? "/?status=ok_dupes" : "/?status=ok");
    }
    catch (Exception ex)
    {
        Console.WriteLine($"Save failed: {ex.Message}");
        return Results.Redirect("/?status=error");
    }
});

// ---------------------------------------------------------------------
// NEW: OVERALL PROGRESS DASHBOARD (US19)
// ---------------------------------------------------------------------
app.MapGet("/dashboard", () =>
{
    return Results.Content("""
    <!DOCTYPE html>
    <html>
    <head>
        <title>Overall Progress</title>
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <style>
            body { font-family: Arial; padding: 16px; max-width: 900px; margin: auto; background: #CCCCCC; }
            .header { background: #1a3d33; color: white; padding: 16px; border-radius: 8px 8px 0 0; font-size: 20px; font-weight: bold; }
            .body-wrap { background: white; border-radius: 0 0 8px 8px; padding: 16px; }
            .navrow { display: flex; gap: 10px; margin-bottom: 14px; }
            .navrow a { flex: 1; text-align: center; padding: 10px; border-radius: 6px; text-decoration: none; font-weight: bold; }
            .navrow a.active { background: #1a3d33; color: white; }
            .navrow a.inactive { background: #eee; color: #333; }
            .kpi-row { display: grid; grid-template-columns: repeat(2, 1fr); gap: 12px; margin-bottom: 16px; }
            .kpi { background: #f2f2f2; border-radius: 8px; padding: 14px; }
            .kpi .label { font-size: 12px; color: #555; }
            .kpi .value { font-size: 26px; font-weight: bold; }
            .panel { background: #f2f2f2; border-radius: 8px; padding: 14px; margin-bottom: 16px; }
            .panel h3 { margin: 0 0 10px 0; font-size: 14px; }
            table { width: 100%; border-collapse: collapse; font-size: 13px; }
            th, td { text-align: left; padding: 6px 4px; border-top: 1px solid #ddd; }
            canvas { max-width: 100%; }
        </style>
    </head>
    <body>
        <div class="header">Tison's Workout Tracker - Overall Progress</div>
        <div class="body-wrap">
            <div class="navrow">
                <a class="active" href="/dashboard">Overall Progress</a>
                <a class="inactive" href="/dashboard/exercise">Exercise Detail</a>
                <a class="inactive" href="/">Log Workout</a>
            </div>

            <div class="kpi-row">
                <div class="kpi"><div class="label">Workouts Tracked</div><div class="value" id="kpiWorkouts">-</div></div>
                <div class="kpi"><div class="label">Avg Sleep (30d)</div><div class="value" id="kpiSleep">-</div></div>
            </div>

            <div class="panel">
                <h3>PR Tracker (max weight per exercise, most recent date)</h3>
                <table id="prTable"><thead><tr><th>Exercise</th><th>PR (lb)</th><th>Achieved</th></tr></thead><tbody></tbody></table>
            </div>

            <div class="panel">
                <h3>Progression (% change from first log)</h3>
                <div style="position: relative; height: 260px;"><canvas id="progressionChart"></canvas></div>
            </div>

            <div class="panel">
                <h3>Volume Trend Over Time (total weight moved per session)</h3>
                <div style="position: relative; height: 260px;"><canvas id="volumeChart"></canvas></div>
            </div>
        </div>

        <script src="https://cdnjs.cloudflare.com/ajax/libs/Chart.js/4.4.1/chart.umd.js"></script>
        <script>
            fetch('/api/overview').then(r => r.json()).then(data => {
                document.getElementById('kpiWorkouts').textContent = data.totalWorkouts;
                document.getElementById('kpiSleep').textContent = data.avgSleep !== null ? data.avgSleep.toFixed(1) + ' hrs' : '-';

                const tbody = document.querySelector('#prTable tbody');
                data.prTracker.forEach(row => {
                    const tr = document.createElement('tr');
                    tr.innerHTML = `<td>${row.exerciseName}</td><td>${row.pr}</td><td>${row.achievedDate}</td>`;
                    tbody.appendChild(tr);
                });

                new Chart(document.getElementById('progressionChart'), {
                    type: 'bar',
                    data: {
                        labels: data.progression.map(p => p.exerciseName),
                        datasets: [{
                            label: '% change',
                            data: data.progression.map(p => Math.round(p.pctChange * 100)),
                            backgroundColor: data.progression.map(p => p.pctChange >= 0 ? '#1D9E75' : '#E24B4A')
                        }]
                    },
                    options: {
                        indexAxis: 'y',
                        responsive: true,
                        maintainAspectRatio: false,
                        plugins: { legend: { display: false } },
                        scales: { x: { ticks: { callback: v => v + '%' } } }
                    }
                });

                new Chart(document.getElementById('volumeChart'), {
                    type: 'line',
                    data: {
                        labels: data.volumeTrend.map(v => v.date),
                        datasets: [{
                            label: 'Total volume',
                            data: data.volumeTrend.map(v => v.totalVolume),
                            borderColor: '#378ADD',
                            backgroundColor: 'rgba(55,138,221,0.1)',
                            fill: true,
                            tension: 0.2
                        }]
                    },
                    options: { responsive: true, maintainAspectRatio: false, plugins: { legend: { display: false } } }
                });
            });
        </script>
    </body>
    </html>
    """, "text/html");
});

app.MapGet("/api/overview", async () =>
{
    using var conn = new SqlConnection(connectionString);
    await conn.OpenAsync();

    int totalWorkouts;
    using (var cmd = new SqlCommand("SELECT COUNT(*) FROM dbo.DailySummary", conn))
        totalWorkouts = (int)(await cmd.ExecuteScalarAsync() ?? 0);

    double? avgSleep;
    using (var cmd = new SqlCommand(
        "SELECT AVG(SleepHours) FROM dbo.DailySummary WHERE [Date] >= DATEADD(day,-30,GETDATE()) AND SleepHours IS NOT NULL", conn))
    {
        var result = await cmd.ExecuteScalarAsync();
        avgSleep = result == DBNull.Value || result == null ? null : Convert.ToDouble(result);
    }

    var prTracker = new List<object>();
    using (var cmd = new SqlCommand("""
        ;WITH Vals AS (
            SELECT e.ExerciseName, d.[Date], TRY_CAST(e.ActualValue AS DECIMAL(10,2)) AS Val
            FROM dbo.Exercises e
            JOIN dbo.DailySummary d ON e.DayID = d.DayID
            WHERE TRY_CAST(e.ActualValue AS DECIMAL(10,2)) IS NOT NULL
        ),
        PRs AS (
            SELECT ExerciseName, MAX(Val) AS PR FROM Vals GROUP BY ExerciseName
        )
        SELECT v.ExerciseName, p.PR, MAX(v.[Date]) AS AchievedDate
        FROM Vals v
        JOIN PRs p ON v.ExerciseName = p.ExerciseName AND v.Val = p.PR
        GROUP BY v.ExerciseName, p.PR
        ORDER BY p.PR DESC;
        """, conn))
    {
        using var reader = await cmd.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            prTracker.Add(new
            {
                exerciseName = reader.GetString(0),
                pr = reader.GetDecimal(1),
                achievedDate = reader.GetDateTime(2).ToString("MM/dd/yy")
            });
        }
    }

    var progression = new List<object>();
    using (var cmd = new SqlCommand("""
        ;WITH Vals AS (
            SELECT e.ExerciseName, d.[Date], TRY_CAST(e.ActualValue AS DECIMAL(10,2)) AS Val,
                   ROW_NUMBER() OVER (PARTITION BY e.ExerciseName ORDER BY d.[Date] ASC) AS rn
            FROM dbo.Exercises e
            JOIN dbo.DailySummary d ON e.DayID = d.DayID
            WHERE TRY_CAST(e.ActualValue AS DECIMAL(10,2)) IS NOT NULL
        ),
        First AS (
            SELECT ExerciseName, Val AS FirstVal FROM Vals WHERE rn = 1
        ),
        Best AS (
            SELECT ExerciseName, MAX(Val) AS PR FROM Vals GROUP BY ExerciseName
        )
        SELECT f.ExerciseName, f.FirstVal, b.PR,
               CASE WHEN f.FirstVal = 0 THEN NULL ELSE (b.PR - f.FirstVal) / f.FirstVal END AS PctChange
        FROM First f
        JOIN Best b ON f.ExerciseName = b.ExerciseName
        ORDER BY PctChange DESC;
        """, conn))
    {
        using var reader = await cmd.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            progression.Add(new
            {
                exerciseName = reader.GetString(0),
                pctChange = reader.IsDBNull(3) ? 0 : (double)reader.GetDecimal(3)
            });
        }
    }

    var volumeTrend = new List<object>();
    using (var cmd = new SqlCommand("""
        SELECT d.[Date], SUM(ISNULL(e.ActualSets,0) * ISNULL(e.ActualReps,0) * TRY_CAST(e.ActualValue AS DECIMAL(10,2))) AS TotalVolume
        FROM dbo.Exercises e
        JOIN dbo.DailySummary d ON e.DayID = d.DayID
        WHERE TRY_CAST(e.ActualValue AS DECIMAL(10,2)) IS NOT NULL
        GROUP BY d.[Date]
        ORDER BY d.[Date];
        """, conn))
    {
        using var reader = await cmd.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            volumeTrend.Add(new
            {
                date = reader.GetDateTime(0).ToString("MM/dd"),
                totalVolume = reader.IsDBNull(1) ? 0 : reader.GetDecimal(1)
            });
        }
    }

    return Results.Json(new { totalWorkouts, avgSleep, prTracker, progression, volumeTrend });
});

// ---------------------------------------------------------------------
// NEW: PER-EXERCISE DETAIL DASHBOARD (US20)
// ---------------------------------------------------------------------
app.MapGet("/dashboard/exercise", () =>
{
    return Results.Content("""
    <!DOCTYPE html>
    <html>
    <head>
        <title>Exercise Detail</title>
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <style>
            body { font-family: Arial; padding: 16px; max-width: 900px; margin: auto; background: #CCCCCC; }
            .header { background: #1a3d33; color: white; padding: 16px; border-radius: 8px 8px 0 0; font-size: 20px; font-weight: bold; }
            .body-wrap { background: white; border-radius: 0 0 8px 8px; padding: 16px; }
            .navrow { display: flex; gap: 10px; margin-bottom: 14px; }
            .navrow a { flex: 1; text-align: center; padding: 10px; border-radius: 6px; text-decoration: none; font-weight: bold; }
            .navrow a.active { background: #1a3d33; color: white; }
            .navrow a.inactive { background: #eee; color: #333; }
            select { width: 100%; padding: 10px; font-size: 15px; margin-bottom: 14px; }
            .kpi-row { display: grid; grid-template-columns: repeat(3, 1fr); gap: 12px; margin-bottom: 16px; }
            .kpi { background: #f2f2f2; border-radius: 8px; padding: 14px; }
            .kpi .label { font-size: 12px; color: #555; }
            .kpi .value { font-size: 22px; font-weight: bold; }
            .panel { background: #f2f2f2; border-radius: 8px; padding: 14px; margin-bottom: 16px; }
            .panel h3 { margin: 0 0 10px 0; font-size: 14px; }
            table { width: 100%; border-collapse: collapse; font-size: 13px; }
            th, td { text-align: left; padding: 6px 4px; border-top: 1px solid #ddd; }
            .pass { color: #1D9E75; font-weight: bold; }
            .fail { color: #E24B4A; font-weight: bold; }
            canvas { max-width: 100%; }
        </style>
    </head>
    <body>
        <div class="header">Tison's Workout Tracker - Exercise Detail</div>
        <div class="body-wrap">
            <div class="navrow">
                <a class="inactive" href="/dashboard">Overall Progress</a>
                <a class="active" href="/dashboard/exercise">Exercise Detail</a>
                <a class="inactive" href="/">Log Workout</a>
            </div>

            <select id="exerciseSelect"></select>

            <div class="kpi-row">
                <div class="kpi"><div class="label">PR</div><div class="value" id="kpiPr">-</div></div>
                <div class="kpi"><div class="label">Sessions</div><div class="value" id="kpiSessions">-</div></div>
                <div class="kpi"><div class="label">Last Performed</div><div class="value" id="kpiLast">-</div></div>
            </div>

            <div class="panel">
                <h3>Weight Progression</h3>
                <div style="position: relative; height: 220px;"><canvas id="progChart"></canvas></div>
            </div>

            <div class="panel">
                <h3>Session History</h3>
                <table id="historyTable"><thead><tr><th>Date</th><th>Sets</th><th>Reps</th><th>Wt</th><th>Status</th></tr></thead><tbody></tbody></table>
            </div>

            <div class="panel">
                <h3>Pass / Fail</h3>
                <div style="position: relative; height: 200px; max-width: 200px; margin: auto;"><canvas id="passFailChart"></canvas></div>
            </div>
        </div>

        <script src="https://cdnjs.cloudflare.com/ajax/libs/Chart.js/4.4.1/chart.umd.js"></script>
        <script>
            let progChart, passFailChart;

            function loadExercise(name) {
                fetch('/api/exercise?name=' + encodeURIComponent(name)).then(r => r.json()).then(data => {
                    document.getElementById('kpiPr').textContent = data.pr ?? '-';
                    document.getElementById('kpiSessions').textContent = data.sessions;
                    document.getElementById('kpiLast').textContent = data.lastPerformed ?? '-';

                    const tbody = document.querySelector('#historyTable tbody');
                    tbody.innerHTML = '';
                    data.history.forEach(row => {
                        const tr = document.createElement('tr');
                        const statusClass = row.status === 'Pass' ? 'pass' : (row.status === 'Fail' ? 'fail' : '');
                        tr.innerHTML = `<td>${row.date}</td><td>${row.sets ?? '-'}</td><td>${row.reps ?? '-'}</td><td>${row.value ?? '-'}</td><td class="${statusClass}">${row.status ?? '-'}</td>`;
                        tbody.appendChild(tr);
                    });

                    if (progChart) progChart.destroy();
                    progChart = new Chart(document.getElementById('progChart'), {
                        type: 'line',
                        data: {
                            labels: data.weightProgression.map(p => p.date),
                            datasets: [{
                                label: 'Weight',
                                data: data.weightProgression.map(p => p.value),
                                borderColor: '#378ADD',
                                backgroundColor: 'rgba(55,138,221,0.1)',
                                fill: true,
                                tension: 0.2
                            }]
                        },
                        options: { responsive: true, maintainAspectRatio: false, plugins: { legend: { display: false } } }
                    });

                    if (passFailChart) passFailChart.destroy();
                    passFailChart = new Chart(document.getElementById('passFailChart'), {
                        type: 'doughnut',
                        data: {
                            labels: ['Pass', 'Fail'],
                            datasets: [{ data: [data.passFail.pass, data.passFail.fail], backgroundColor: ['#1D9E75', '#E24B4A'] }]
                        },
                        options: { responsive: true, maintainAspectRatio: false }
                    });
                });
            }

            fetch('/api/exercises').then(r => r.json()).then(names => {
                const select = document.getElementById('exerciseSelect');
                names.forEach(n => {
                    const opt = document.createElement('option');
                    opt.value = n;
                    opt.textContent = n;
                    select.appendChild(opt);
                });
                select.addEventListener('change', () => loadExercise(select.value));
                if (names.length > 0) loadExercise(names[0]);
            });
        </script>
    </body>
    </html>
    """, "text/html");
});

app.MapGet("/api/exercises", async () =>
{
    var names = new List<string>();
    using var conn = new SqlConnection(connectionString);
    await conn.OpenAsync();
    using var cmd = new SqlCommand("SELECT DISTINCT ExerciseName FROM dbo.Exercises ORDER BY ExerciseName", conn);
    using var reader = await cmd.ExecuteReaderAsync();
    while (await reader.ReadAsync()) names.Add(reader.GetString(0));
    return Results.Json(names);
});

app.MapGet("/api/exercise", async (string name) =>
{
    using var conn = new SqlConnection(connectionString);
    await conn.OpenAsync();

    decimal? pr = null;
    using (var cmd = new SqlCommand(
        "SELECT MAX(TRY_CAST(ActualValue AS DECIMAL(10,2))) FROM dbo.Exercises WHERE ExerciseName = @name", conn))
    {
        cmd.Parameters.AddWithValue("@name", name);
        var result = await cmd.ExecuteScalarAsync();
        pr = result == DBNull.Value || result == null ? null : Convert.ToDecimal(result);
    }

    int sessions;
    using (var cmd = new SqlCommand("SELECT COUNT(*) FROM dbo.Exercises WHERE ExerciseName = @name", conn))
    {
        cmd.Parameters.AddWithValue("@name", name);
        sessions = (int)(await cmd.ExecuteScalarAsync() ?? 0);
    }

    string? lastPerformed = null;
    using (var cmd = new SqlCommand("""
        SELECT MAX(d.[Date]) FROM dbo.Exercises e
        JOIN dbo.DailySummary d ON e.DayID = d.DayID
        WHERE e.ExerciseName = @name
        """, conn))
    {
        cmd.Parameters.AddWithValue("@name", name);
        var result = await cmd.ExecuteScalarAsync();
        lastPerformed = result == DBNull.Value || result == null ? null : Convert.ToDateTime(result).ToString("MM/dd/yy");
    }

    var weightProgression = new List<object>();
    using (var cmd = new SqlCommand("""
        SELECT d.[Date], TRY_CAST(e.ActualValue AS DECIMAL(10,2)) AS Val
        FROM dbo.Exercises e
        JOIN dbo.DailySummary d ON e.DayID = d.DayID
        WHERE e.ExerciseName = @name AND TRY_CAST(e.ActualValue AS DECIMAL(10,2)) IS NOT NULL
        ORDER BY d.[Date]
        """, conn))
    {
        cmd.Parameters.AddWithValue("@name", name);
        using var reader = await cmd.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            weightProgression.Add(new { date = reader.GetDateTime(0).ToString("MM/dd"), value = reader.GetDecimal(1) });
        }
    }

    var history = new List<object>();
    using (var cmd = new SqlCommand("""
        SELECT d.[Date], e.ActualSets, e.ActualReps, e.ActualValue, e.CompletionStatus
        FROM dbo.Exercises e
        JOIN dbo.DailySummary d ON e.DayID = d.DayID
        WHERE e.ExerciseName = @name
        ORDER BY d.[Date] DESC
        """, conn))
    {
        cmd.Parameters.AddWithValue("@name", name);
        using var reader = await cmd.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            history.Add(new
            {
                date = reader.GetDateTime(0).ToString("MM/dd/yy"),
                sets = reader.IsDBNull(1) ? (int?)null : reader.GetInt32(1),
                reps = reader.IsDBNull(2) ? (int?)null : reader.GetInt32(2),
                value = reader.IsDBNull(3) ? null : reader.GetString(3),
                status = reader.IsDBNull(4) ? null : reader.GetString(4)
            });
        }
    }

    int pass = 0, fail = 0;
    using (var cmd = new SqlCommand(
        "SELECT CompletionStatus, COUNT(*) FROM dbo.Exercises WHERE ExerciseName = @name GROUP BY CompletionStatus", conn))
    {
        cmd.Parameters.AddWithValue("@name", name);
        using var reader = await cmd.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            if (!reader.IsDBNull(0))
            {
                var status = reader.GetString(0);
                var count = reader.GetInt32(1);
                if (status == "Pass") pass = count;
                else if (status == "Fail") fail = count;
            }
        }
    }

    return Results.Json(new { pr, sessions, lastPerformed, weightProgression, history, passFail = new { pass, fail } });
});

app.Run();