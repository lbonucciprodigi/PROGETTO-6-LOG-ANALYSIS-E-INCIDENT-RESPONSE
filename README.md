# PROGETTO-6-LOG-ANALYSIS-E-INCIDENT-RESPONSE


### Scenario
Security Operations Center (SOC) necessita di strumenti per analisi rapida log di sistema, identificazione pattern sospetti e incident response.

### Obiettivi
1. Script parsing log multipli (syslog, auth.log, apache)
2. Identificazione tentativi accesso falliti
3. Top IP sorgenti attacchi
4. Analisi anomalie temporali (spike accessi)
5. Report incident con timeline

### Requisiti Tecnici
- Analisi log: `/var/log/auth.log`, `/var/log/syslog`, `/var/log/apache2/access.log`
- Estrazione: failed SSH logins, sudo usage, HTTP errors
- Pattern: brute force SSH, port scanning, SQL injection attempts
- Output: JSON e HTML report
- Timeline eventi critici ultimi 7 giorni

### Divisione Compiti Suggerita
- **Membro A**: Parsing auth.log e SSH analysis
- **Membro B**: Apache logs e web attacks
- **Membro C**: Aggregazione, report, timeline

### Deliverables Specifici
```bash
analyze-logs.sh          # Script analisi principale
extract-incidents.sh     # Estrazione eventi critici
incident-report.html     # Report con grafici
top-attackers.txt        # Lista IP sospetti
timeline.json            # Timeline eventi in JSON
```

### Comandi Utili
```bash
grep "incorrect password" /var/log/auth.log | awk '{print $(NF-3)}' | sort | uniq -c | sort -rn
grep "sudo:" /var/log/auth.log | grep "COMMAND"
awk '$9 ~ /^[45]/ {print $1, $7, $9}' /var/log/apache2/access.log
journalctl --since "7 days ago" --priority=err
# JSON: jq -n '{events: [...]}'
```





###IMPORTANT
```Run initialization.sh once when installing this for the first time
```





