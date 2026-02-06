#!/bin/bash

journalctl -p err --since "7 days ago" -o json > timeline.json


