#!/usr/bin/env python3
# Sudo Log Analyzer - Generates HTML report from output.txt
# Reads output.txt and creates sudo_log_report.html with interactive visualizations


import re
from datetime import datetime
from collections import Counter, defaultdict
import json

def parse_log_file(filename):
    """Parse the sudo log file and extract relevant information."""
    logs = []
    log_pattern = r'^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d+\+\d{2}:\d{2})\s+\S+\s+sudo:\s+(\S+)\s+:\s+TTY=(\S+)\s+;\s+PWD=(.+?)\s+;\s+USER=(\S+)\s+;\s+COMMAND=(.+)$'
    
    try:
        with open(filename, 'r') as f:
            for line in f:
                match = re.match(log_pattern, line.strip())
                if match:
                    timestamp, user, tty, pwd, target_user, command = match.groups()
                    # Remove /usr/bin/ and /bin/ prefixes from commands
                    command = command.replace('/usr/bin/', '').replace('/bin/', '')
                    
                    logs.append({
                        'timestamp': timestamp,
                        'user': user,
                        'tty': tty,
                        'pwd': pwd,
                        'target_user': target_user,
                        'command': command
                    })
    except FileNotFoundError:
        print("Error: " + filename + " not found!")
        return []
    
    return logs

def analyze_logs(logs):
    """Analyze logs and extract statistics."""
    if not logs:
        return None
    
    # Extract command names (first word)
    commands = [log['command'].split()[0] for log in logs]
    command_counts = Counter(commands)
    
    # Extract dates
    dates = [log['timestamp'].split('T')[0] for log in logs]
    date_counts = Counter(dates)
    
    # Extract hours
    hours = defaultdict(int)
    for log in logs:
        dt = datetime.fromisoformat(log['timestamp'])
        hours[dt.hour] += 1
    
    # Get most used command
    most_used = command_counts.most_common(1)[0] if command_counts else ('N/A', 0)
    
    return {
        'total_commands': len(logs),
        'unique_commands': len(command_counts),
        'days_active': len(date_counts),
        'most_used_command': most_used[0],
        'most_used_count': most_used[1],
        'command_counts': dict(command_counts),
        'date_counts': dict(date_counts),
        'hour_counts': dict(hours),
        'user': logs[0]['user'] if logs else 'N/A'
    }

def generate_html(logs, stats):
    """Generate HTML report with embedded data."""
    
    # Convert logs to JSON for embedding
    logs_json = json.dumps(logs)
    stats_json = json.dumps(stats)
    
    html_content = '''<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Sudo Command Log Analysis Report</title>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            padding: 20px;
            min-height: 100vh;
        }
        
        .container {
            max-width: 1400px;
            margin: 0 auto;
            background: white;
            border-radius: 20px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            overflow: hidden;
        }
        
        header {
            background: linear-gradient(135deg, #2d3748 0%, #1a202c 100%);
            color: white;
            padding: 40px;
            text-align: center;
        }
        
        header h1 {
            font-size: 2.5em;
            margin-bottom: 10px;
        }
        
        header p {
            font-size: 1.1em;
            opacity: 0.9;
        }
        
        .generated-info {
            background: #e6fffa;
            padding: 15px 40px;
            text-align: center;
            color: #234e52;
            font-size: 0.95em;
        }
        
        .stats-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            padding: 40px;
            background: #f7fafc;
        }
        
        .stat-card {
            background: white;
            padding: 30px;
            border-radius: 15px;
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
            text-align: center;
            transition: transform 0.3s ease;
        }
        
        .stat-card:hover {
            transform: translateY(-5px);
            box-shadow: 0 8px 15px rgba(0,0,0,0.2);
        }
        
        .stat-card h3 {
            color: #667eea;
            font-size: 3em;
            margin-bottom: 10px;
        }
        
        .stat-card p {
            color: #4a5568;
            font-size: 1.1em;
        }
        
        .charts-section {
            padding: 40px;
        }
        
        .chart-container {
            background: white;
            padding: 30px;
            border-radius: 15px;
            margin-bottom: 30px;
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
        }
        
        .chart-container h2 {
            color: #2d3748;
            margin-bottom: 20px;
            font-size: 1.8em;
        }
        
        .log-table-container {
            padding: 40px;
            background: #f7fafc;
        }
        
        .log-table-container h2 {
            color: #2d3748;
            margin-bottom: 20px;
            font-size: 1.8em;
        }
        
        table {
            width: 100%;
            border-collapse: collapse;
            background: white;
            border-radius: 15px;
            overflow: hidden;
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
        }
        
        thead {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
        }
        
        th, td {
            padding: 15px;
            text-align: left;
        }
        
        th {
            font-weight: 600;
            text-transform: uppercase;
            font-size: 0.9em;
            letter-spacing: 0.5px;
        }
        
        tbody tr {
            border-bottom: 1px solid #e2e8f0;
        }
        
        tbody tr:hover {
            background: #f7fafc;
        }
        
        tbody tr:last-child {
            border-bottom: none;
        }
        
        .command-cell {
            font-family: 'Courier New', monospace;
            font-size: 0.9em;
            color: #2d3748;
        }
        
        .date-badge {
            display: inline-block;
            padding: 5px 10px;
            background: #667eea;
            color: white;
            border-radius: 5px;
            font-size: 0.85em;
        }
        
        canvas {
            max-height: 400px;
        }
        
        footer {
            background: #2d3748;
            color: white;
            padding: 20px;
            text-align: center;
            font-size: 0.9em;
        }
    </style>
</head>
<body>
    <div class="container">
        <header>
            <h1>Sudo Command Log Analysis Report</h1>
            <p>System Analysis | User: ''' + stats['user'] + '''</p>
        </header>
        
        <div class="generated-info">
            Report generated on ''' + datetime.now().strftime('%Y-%m-%d %H:%M:%S') + ''' from output.txt
        </div>
        
        <div class="stats-grid">
            <div class="stat-card">
                <h3>''' + str(stats['total_commands']) + '''</h3>
                <p>Total Commands</p>
            </div>
            <div class="stat-card">
                <h3>''' + str(stats['days_active']) + '''</h3>
                <p>Days Active</p>
            </div>
            <div class="stat-card">
                <h3>''' + str(stats['unique_commands']) + '''</h3>
                <p>Unique Commands</p>
            </div>
            <div class="stat-card">
                <h3>''' + stats['most_used_command'] + '''</h3>
                <p>Most Used (''' + str(stats['most_used_count']) + '''x)</p>
            </div>
        </div>
        
        <div class="charts-section">
            <div class="chart-container">
                <h2>Command Frequency Distribution</h2>
                <canvas id="commandChart"></canvas>
            </div>
            
            <div class="chart-container">
                <h2>Activity Timeline (by Hour)</h2>
                <canvas id="timelineChart"></canvas>
            </div>
            
            <div class="chart-container">
                <h2>Commands by Date</h2>
                <canvas id="dateChart"></canvas>
            </div>
        </div>
        
        <div class="log-table-container">
            <h2>Complete Command Log (''' + str(stats['total_commands']) + ''' entries)</h2>
            <table>
                <thead>
                    <tr>
                        <th>Timestamp</th>
                        <th>Command</th>
                        <th>Working Directory</th>
                    </tr>
                </thead>
                <tbody id="logTable">
                </tbody>
            </table>
        </div>
        
        <footer>
            Generated by Sudo Log Analyzer | Data source: output.txt
        </footer>
    </div>
    
    <script>
        // Embedded data
        const logs = ''' + logs_json + ''';
        const stats = ''' + stats_json + ''';
        
        // Populate table
        const tableBody = document.getElementById('logTable');
        logs.forEach(log => {
            const date = new Date(log.timestamp);
            const row = `
                <tr>
                    <td><span class="date-badge">${date.toLocaleString('en-GB')}</span></td>
                    <td class="command-cell">${log.command}</td>
                    <td style="font-size: 0.85em; color: #718096;">${log.pwd}</td>
                </tr>
            `;
            tableBody.innerHTML += row;
        });
        
        // Chart 1: Command Distribution
        new Chart(document.getElementById('commandChart'), {
            type: 'bar',
            data: {
                labels: Object.keys(stats.command_counts),
                datasets: [{
                    label: 'Command Usage Count',
                    data: Object.values(stats.command_counts),
                    backgroundColor: [
                        '#667eea', '#764ba2', '#f093fb', '#4facfe',
                        '#43e97b', '#fa709a', '#fee140', '#30cfd0',
                        '#a8edea', '#fed6e3', '#c471ed'
                    ],
                    borderWidth: 0,
                    borderRadius: 8
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: true,
                plugins: {
                    legend: { display: false }
                },
                scales: {
                    y: {
                        beginAtZero: true,
                        ticks: { stepSize: 1 }
                    }
                }
            }
        });
        
        // Chart 2: Timeline by hour
        const hours = Array.from({length: 24}, (_, i) => i);
        const hourData = hours.map(h => stats.hour_counts[h] || 0);
        
        new Chart(document.getElementById('timelineChart'), {
            type: 'line',
            data: {
                labels: hours.map(h => `${h}:00`),
                datasets: [{
                    label: 'Commands per Hour',
                    data: hourData,
                    borderColor: '#667eea',
                    backgroundColor: 'rgba(102, 126, 234, 0.1)',
                    fill: true,
                    tension: 0.4,
                    pointRadius: 5,
                    pointHoverRadius: 7
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: true,
                plugins: {
                    legend: { display: true }
                },
                scales: {
                    y: {
                        beginAtZero: true,
                        ticks: { stepSize: 1 }
                    }
                }
            }
        });
        
        // Chart 3: Commands by date
        const colors = ['#764ba2', '#667eea', '#f093fb', '#4facfe', '#43e97b'];
        
        new Chart(document.getElementById('dateChart'), {
            type: 'bar',
            data: {
                labels: Object.keys(stats.date_counts),
                datasets: [{
                    label: 'Commands per Day',
                    data: Object.values(stats.date_counts),
                    backgroundColor: colors.slice(0, Object.keys(stats.date_counts).length),
                    borderWidth: 0,
                    borderRadius: 8
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: true,
                plugins: {
                    legend: { display: false }
                },
                scales: {
                    y: {
                        beginAtZero: true,
                        ticks: { stepSize: 5 }
                    }
                }
            }
        });
    </script>
</body>
</html>'''
    
    return html_content

def main():
    """Main function to generate the report."""
    input_file = 'output.txt'
    output_file = 'sudo_log_report.html'
    
    print("Reading " + input_file + "...")
    logs = parse_log_file(input_file)
    
    if not logs:
        print("No valid log entries found!")
        return
    
    print("Found " + str(len(logs)) + " log entries")
    print("Analyzing logs...")
    
    stats = analyze_logs(logs)
    
    print("Statistics:")
    print("   - Total commands: " + str(stats['total_commands']))
    print("   - Unique commands: " + str(stats['unique_commands']))
    print("   - Days active: " + str(stats['days_active']))
    print("   - Most used: " + stats['most_used_command'] + " (" + str(stats['most_used_count']) + "x)")
    
    print("Generating HTML report...")
    html = generate_html(logs, stats)
    
    with open(output_file, 'w') as f:
        f.write(html)
    
    print("Report generated: " + output_file)
    print("Open " + output_file + " in your browser to view the analysis!")

if __name__ == '__main__':
    main()
