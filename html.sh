#!/bin/bash

#############################################
# generate-html-report.sh
# Genera report HTML da file .tmp analizzati
#############################################

# File di input
FAILED_LOGINS="failed_logins.tmp"
SUDO_EVENTS="sudo_events.tmp"
WEB_ATTACKS="web_attacks.tmp"
HTTP_ERRORS="http_errors.tmp"
SYSTEM_ERRORS="system_errors.tmp"

# File di output
OUTPUT_HTML="incident-report.html"

echo "[*] Generazione report HTML..."

# Verifica esistenza file
for file in "$FAILED_LOGINS" "$SUDO_EVENTS" "$WEB_ATTACKS"; do
    if [ ! -f "$file" ]; then
        echo "[!] Warning: $file non trovato, creo file vuoto..."
        touch "$file"
    fi
done

# Calcola statistiche
total_failed=$(wc -l < "$FAILED_LOGINS" 2>/dev/null || echo 0)
total_sudo=$(wc -l < "$SUDO_EVENTS" 2>/dev/null || echo 0)
total_web=$(wc -l < "$WEB_ATTACKS" 2>/dev/null || echo 0)
total_http_err=$(wc -l < "$HTTP_ERRORS" 2>/dev/null || echo 0)
total_sys_err=$(wc -l < "$SYSTEM_ERRORS" 2>/dev/null || echo 0)
total_events=$((total_failed + total_sudo + total_web + total_http_err + total_sys_err))

# Conta unique IPs
unique_ips=$(cat "$FAILED_LOGINS" "$WEB_ATTACKS" 2>/dev/null | awk -F'|' '{print $4}' | sort -u | wc -l)

# Conta eventi HIGH severity (brute force + web attacks)
high_severity=$((total_failed + total_web))

# Prepara dati per grafici Chart.js
# Top 10 Attacking IPs
top_ips_data=$(cat "$FAILED_LOGINS" "$WEB_ATTACKS" 2>/dev/null | awk -F'|' '{print $4}' | \
    sort | uniq -c | sort -rn | head -10 | \
    awk '{printf "{\"ip\":\"%s\",\"count\":%d},", $2, $1}' | sed 's/,$//')

# Distribuzione tipi di attacco
attack_types_data=$(cat "$WEB_ATTACKS" 2>/dev/null | awk -F'|' '{print $2}' | \
    sort | uniq -c | \
    awk '{printf "{\"type\":\"%s\",\"count\":%d},", $2, $1}' | sed 's/,$//')

# Genera HTML
cat > "$OUTPUT_HTML" << 'HTMLEOF'
<!DOCTYPE html>
<html lang="it">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Security Incident Report - SOC Analysis</title>
    <script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.min.js"></script>
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
            color: #333;
            line-height: 1.6;
        }
        
        .container {
            max-width: 1400px;
            margin: 0 auto;
            background: white;
            border-radius: 15px;
            box-shadow: 0 10px 40px rgba(0,0,0,0.3);
            overflow: hidden;
        }
        
        header {
            background: linear-gradient(135deg, #1e3c72 0%, #2a5298 100%);
            color: white;
            padding: 40px;
            text-align: center;
            position: relative;
        }
        
        header h1 {
            font-size: 2.8em;
            margin-bottom: 10px;
            text-shadow: 2px 2px 4px rgba(0,0,0,0.3);
        }
        
        .meta-info {
            background: rgba(255,255,255,0.15);
            padding: 20px;
            border-radius: 10px;
            display: inline-block;
            margin-top: 20px;
            backdrop-filter: blur(10px);
        }
        
        .content {
            padding: 40px;
        }
        
        .section {
            margin-bottom: 50px;
        }
        
        .section h2 {
            color: #2a5298;
            border-bottom: 3px solid #667eea;
            padding-bottom: 10px;
            margin-bottom: 30px;
            font-size: 1.8em;
        }
        
        .stats-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
            gap: 25px;
            margin-bottom: 40px;
        }
        
        .stat-card {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 30px;
            border-radius: 15px;
            box-shadow: 0 8px 20px rgba(0,0,0,0.2);
            transition: transform 0.3s, box-shadow 0.3s;
        }
        
        .stat-card:hover {
            transform: translateY(-5px);
            box-shadow: 0 12px 30px rgba(0,0,0,0.3);
        }
        
        .stat-card h3 {
            font-size: 1em;
            opacity: 0.9;
            margin-bottom: 15px;
            text-transform: uppercase;
            letter-spacing: 1px;
        }
        
        .stat-card .number {
            font-size: 3em;
            font-weight: bold;
            text-shadow: 2px 2px 4px rgba(0,0,0,0.2);
        }
        
        .stat-card .icon {
            font-size: 2.5em;
            opacity: 0.3;
            float: right;
        }
        
        .charts-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(500px, 1fr));
            gap: 30px;
            margin-bottom: 40px;
        }
        
        .chart-container {
            background: #f8f9fa;
            padding: 25px;
            border-radius: 10px;
            box-shadow: 0 5px 15px rgba(0,0,0,0.1);
        }
        
        .chart-container h3 {
            color: #2a5298;
            margin-bottom: 20px;
            font-size: 1.3em;
        }
        
        table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 20px;
            background: white;
            box-shadow: 0 5px 15px rgba(0,0,0,0.1);
            border-radius: 8px;
            overflow: hidden;
        }
        
        thead {
            background: linear-gradient(135deg, #2a5298 0%, #1e3c72 100%);
            color: white;
        }
        
        th {
            padding: 15px;
            text-align: left;
            font-weight: 600;
            text-transform: uppercase;
            font-size: 0.9em;
            letter-spacing: 0.5px;
        }
        
        td {
            padding: 12px 15px;
            border-bottom: 1px solid #e9ecef;
        }
        
        tbody tr:hover {
            background: #f1f3f5;
            transition: background 0.2s;
        }
        
        tbody tr:last-child td {
            border-bottom: none;
        }
        
        .severity-badge {
            display: inline-block;
            padding: 5px 12px;
            border-radius: 15px;
            font-size: 0.8em;
            font-weight: bold;
            text-transform: uppercase;
        }
        
        .severity-HIGH {
            background: #dc3545;
            color: white;
        }
        
        .severity-MEDIUM {
            background: #ffc107;
            color: #333;
        }
        
        .severity-LOW {
            background: #28a745;
            color: white;
        }
        
        .ip-address {
            font-family: 'Courier New', monospace;
            background: #e9ecef;
            padding: 4px 8px;
            border-radius: 4px;
            font-size: 0.95em;
        }
        
        .attack-type {
            font-weight: 600;
            color: #2a5298;
        }
        
        footer {
            background: #2a5298;
            color: white;
            text-align: center;
            padding: 25px;
            font-size: 0.9em;
        }
        
        footer p {
            margin: 5px 0;
        }
        
        .alert-box {
            background: #fff3cd;
            border-left: 5px solid #ffc107;
            padding: 20px;
            border-radius: 5px;
            margin-bottom: 30px;
        }
        
        .alert-box strong {
            color: #856404;
        }
        
        @media (max-width: 768px) {
            .charts-grid {
                grid-template-columns: 1fr;
            }
            
            header h1 {
                font-size: 2em;
            }
            
            .content {
                padding: 20px;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <header>
            <h1>🛡️ Security Incident Report</h1>
            <div class="meta-info">
                <strong>📅 Generated:</strong> <span id="report-date">REPORT_DATE</span><br>
                <strong>⏱️ Time Range:</strong> Last 7 days<br>
                <strong>🖥️ System:</strong> Security Operations Center
            </div>
        </header>
        
        <div class="content">
            
            <!-- Alert Box -->
            <div class="alert-box">
                <strong>⚠️ ATTENTION:</strong> This report contains TOTAL_EVENTS security events requiring immediate review.
                UNIQUE_IPS unique IP addresses have been flagged as potential threats.
            </div>
            
            <!-- Statistics Section -->
            <div class="section">
                <h2>📊 Executive Summary</h2>
                <div class="stats-grid">
                    <div class="stat-card">
                        <span class="icon">📋</span>
                        <h3>Total Events</h3>
                        <div class="number">TOTAL_EVENTS</div>
                    </div>
                    <div class="stat-card">
                        <h3>Failed Logins</h3>
                        <div class="number">TOTAL_FAILED</div>
                    </div>
                    <div class="stat-card">
                        <h3>Web Attacks</h3>
                        <div class="number">TOTAL_WEB</div>
                    </div>
                    <div class="stat-card">
                        <h3>Unique Attackers</h3>
                        <div class="number">UNIQUE_IPS</div>
                    </div>
                    <div class="stat-card">
                        <h3>HTTP Errors</h3>
                        <div class="number">TOTAL_HTTP</div>
                    </div>
                    <div class="stat-card">
                        <h3>Critical Events</h3>
                        <div class="number">HIGH_SEVERITY</div>
                    </div>
                </div>
            </div>
            
            <!-- Charts Section -->
            <div class="section">
                <h2>📈 Visual Analysis</h2>
                <div class="charts-grid">
                    <div class="chart-container">
                        <h3>Top 10 Attacking IPs</h3>
                        <canvas id="topIPsChart"></canvas>
                    </div>
                    <div class="chart-container">
                        <h3>Attack Types Distribution</h3>
                        <canvas id="attackTypesChart"></canvas>
                    </div>
                </div>
                <div class="charts-grid">
                    <div class="chart-container">
                        <h3>Events by Category</h3>
                        <canvas id="categoryChart"></canvas>
                    </div>
                </div>
            </div>
            
            <!-- Top Attackers Table -->
            <div class="section">
                <h2>🎯 Top Attacking IPs</h2>
                <table>
                    <thead>
                        <tr>
                            <th>#</th>
                            <th>IP Address</th>
                            <th>Total Attempts</th>
                            <th>Attack Types</th>
                            <th>Severity</th>
                        </tr>
                    </thead>
                    <tbody id="top-attackers-table">
                        <!-- Populated by script -->
                    </tbody>
                </table>
            </div>
            
            <!-- Failed Logins Details -->
            <div class="section">
                <h2>🔓 Failed Login Attempts</h2>
                <table>
                    <thead>
                        <tr>
                            <th>Timestamp</th>
                            <th>Type</th>
                            <th>Username</th>
                            <th>Source IP</th>
                            <th>Port</th>
                        </tr>
                    </thead>
                    <tbody id="failed-logins-table">
                        <!-- Populated by script -->
                    </tbody>
                </table>
            </div>
            
            <!-- Web Attacks Details -->
            <div class="section">
                <h2>💉 Web Attack Attempts</h2>
                <table>
                    <thead>
                        <tr>
                            <th>Timestamp</th>
                            <th>Attack Type</th>
                            <th>Source IP</th>
                            <th>Request</th>
                        </tr>
                    </thead>
                    <tbody id="web-attacks-table">
                        <!-- Populated by script -->
                    </tbody>
                </table>
            </div>
            
            <!-- Sudo Events -->
            <div class="section">
                <h2>⚙️ Sudo Usage Log</h2>
                <table>
                    <thead>
                        <tr>
                            <th>Timestamp</th>
                            <th>User</th>
                            <th>Command</th>
                        </tr>
                    </thead>
                    <tbody id="sudo-events-table">
                        <!-- Populated by script -->
                    </tbody>
                </table>
            </div>
            
        </div>
        
        <footer>
            <p><strong>Security Operations Center (SOC)</strong></p>
            <p>Automated Incident Response System v1.0</p>
            <p>⚠️ CONFIDENTIAL - This report contains sensitive security information</p>
        </footer>
    </div>

    <script>
        // Dati inseriti da bash
        const topIPsData = [TOP_IPS_DATA];
        const attackTypesData = [ATTACK_TYPES_DATA];
        
        const categoryData = {
            labels: ['Failed Logins', 'Web Attacks', 'HTTP Errors', 'System Errors', 'Sudo Events'],
            data: [TOTAL_FAILED, TOTAL_WEB, TOTAL_HTTP, TOTAL_SYS, TOTAL_SUDO]
        };
        
        // Chart 1: Top IPs
        if (topIPsData.length > 0 && topIPsData[0].ip) {
            const ctx1 = document.getElementById('topIPsChart').getContext('2d');
            new Chart(ctx1, {
                type: 'bar',
                data: {
                    labels: topIPsData.map(item => item.ip),
                    datasets: [{
                        label: 'Attack Attempts',
                        data: topIPsData.map(item => item.count),
                        backgroundColor: 'rgba(102, 126, 234, 0.8)',
                        borderColor: 'rgba(102, 126, 234, 1)',
                        borderWidth: 2
                    }]
                },
                options: {
                    responsive: true,
                    plugins: {
                        legend: { display: false }
                    },
                    scales: {
                        y: {
                            beginAtZero: true,
                            ticks: { precision: 0 }
                        }
                    }
                }
            });
        }
        
        // Chart 2: Attack Types
        if (attackTypesData.length > 0 && attackTypesData[0].type) {
            const ctx2 = document.getElementById('attackTypesChart').getContext('2d');
            new Chart(ctx2, {
                type: 'doughnut',
                data: {
                    labels: attackTypesData.map(item => item.type),
                    datasets: [{
                        data: attackTypesData.map(item => item.count),
                        backgroundColor: [
                            'rgba(220, 53, 69, 0.8)',
                            'rgba(255, 193, 7, 0.8)',
                            'rgba(40, 167, 69, 0.8)',
                            'rgba(102, 126, 234, 0.8)',
                            'rgba(118, 75, 162, 0.8)'
                        ],
                        borderWidth: 2
                    }]
                },
                options: {
                    responsive: true,
                    plugins: {
                        legend: { position: 'bottom' }
                    }
                }
            });
        }
        
        // Chart 3: Category Distribution
        const ctx3 = document.getElementById('categoryChart').getContext('2d');
        new Chart(ctx3, {
            type: 'pie',
            data: {
                labels: categoryData.labels,
                datasets: [{
                    data: categoryData.data,
                    backgroundColor: [
                        'rgba(220, 53, 69, 0.8)',
                        'rgba(255, 193, 7, 0.8)',
                        'rgba(40, 167, 69, 0.8)',
                        'rgba(102, 126, 234, 0.8)',
                        'rgba(118, 75, 162, 0.8)'
                    ],
                    borderWidth: 2
                }]
            },
            options: {
                responsive: true,
                plugins: {
                    legend: { position: 'bottom' }
                }
            }
        });
    </script>
</body>
</html>
HTMLEOF

# Sostituisci placeholder con dati reali
sed -i "s/REPORT_DATE/$(date '+%Y-%m-%d %H:%M:%S')/g" "$OUTPUT_HTML"
sed -i "s/TOTAL_EVENTS/$total_events/g" "$OUTPUT_HTML"
sed -i "s/TOTAL_FAILED/$total_failed/g" "$OUTPUT_HTML"
sed -i "s/TOTAL_WEB/$total_web/g" "$OUTPUT_HTML"
sed -i "s/TOTAL_HTTP/$total_http_err/g" "$OUTPUT_HTML"
sed -i "s/TOTAL_SYS/$total_sys_err/g" "$OUTPUT_HTML"
sed -i "s/TOTAL_SUDO/$total_sudo/g" "$OUTPUT_HTML"
sed -i "s/UNIQUE_IPS/$unique_ips/g" "$OUTPUT_HTML"
sed -i "s/HIGH_SEVERITY/$high_severity/g" "$OUTPUT_HTML"
sed -i "s/TOP_IPS_DATA/$top_ips_data/g" "$OUTPUT_HTML"
sed -i "s/ATTACK_TYPES_DATA/$attack_types_data/g" "$OUTPUT_HTML"

# Popola tabelle con dati reali tramite script bash
# Top Attackers Table
echo "<script>" >> "$OUTPUT_HTML"
echo "const topAttackersTable = document.getElementById('top-attackers-table');" >> "$OUTPUT_HTML"

counter=1
cat "$FAILED_LOGINS" "$WEB_ATTACKS" 2>/dev/null | awk -F'|' '{print $4}' | \
    sort | uniq -c | sort -rn | head -20 | while read count ip; do
    
    severity="HIGH"
    if [ "$count" -lt 10 ]; then
        severity="MEDIUM"
    fi
    if [ "$count" -lt 5 ]; then
        severity="LOW"
    fi
    
    echo "topAttackersTable.innerHTML += '<tr><td>$counter</td><td><span class=\"ip-address\">$ip</span></td><td>$count</td><td>Mixed</td><td><span class=\"severity-badge severity-$severity\">$severity</span></td></tr>';" >> "$OUTPUT_HTML"
    counter=$((counter + 1))
done

# Failed Logins Table
echo "const failedLoginsTable = document.getElementById('failed-logins-table');" >> "$OUTPUT_HTML"
head -50 "$FAILED_LOGINS" 2>/dev/null | while IFS='|' read timestamp type username ip port; do
    echo "failedLoginsTable.innerHTML += '<tr><td>$timestamp</td><td><span class=\"attack-type\">$type</span></td><td>$username</td><td><span class=\"ip-address\">$ip</span></td><td>$port</td></tr>';" >> "$OUTPUT_HTML"
done

# Web Attacks Table
echo "const webAttacksTable = document.getElementById('web-attacks-table');" >> "$OUTPUT_HTML"
head -50 "$WEB_ATTACKS" 2>/dev/null | while IFS='|' read timestamp type ip request; do
    # Escapa quotes nel request
    request_escaped=$(echo "$request" | sed "s/'/\\\'/g" | sed 's/"/\\"/g')
    echo "webAttacksTable.innerHTML += '<tr><td>$timestamp</td><td><span class=\"attack-type\">$type</span></td><td><span class=\"ip-address\">$ip</span></td><td style=\"font-size:0.85em;\">$request_escaped</td></tr>';" >> "$OUTPUT_HTML"
done

# Sudo Events Table
echo "const sudoEventsTable = document.getElementById('sudo-events-table');" >> "$OUTPUT_HTML"
head -50 "$SUDO_EVENTS" 2>/dev/null | while IFS='|' read timestamp type user command; do
    command_escaped=$(echo "$command" | sed "s/'/\\\'/g" | sed 's/"/\\"/g')
    echo "sudoEventsTable.innerHTML += '<tr><td>$timestamp</td><td>$user</td><td style=\"font-family:monospace;font-size:0.9em;\">$command_escaped</td></tr>';" >> "$OUTPUT_HTML"
done

echo "</script>" >> "$OUTPUT_HTML"

echo -e "\n[✓] Report HTML generato con successo!"
echo "[✓] File: $OUTPUT_HTML"
echo "[i] Apri con: firefox $OUTPUT_HTML"
echo ""

# Statistiche finali
file_size=$(du -h "$OUTPUT_HTML" | cut -f1)
echo "Dimensione file: $file_size"
echo "Eventi totali processati: $total_events"
echo "Tabelle generate: 4 (Top Attackers, Failed Logins, Web Attacks, Sudo Events)"
echo "Grafici generati: 3 (Top IPs, Attack Types, Category Distribution)"




