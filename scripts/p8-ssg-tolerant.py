#!/usr/bin/env python3
"""Copie du playbook SSG où chaque tâche tolère son échec (ignore_errors) afin que la remédiation CIS
s'applique à toutes les règles même si certaines tâches sont inadaptées à l'environnement
(service absent, nom de paquet Debian erroné…). Les échecs restent visibles et sont comptés.
Usage : p8-ssg-tolerant.py <playbook_ssg.yml> <sortie.yml>"""
import sys

import yaml

src, dst = sys.argv[1], sys.argv[2]
plays = yaml.safe_load(open(src))
n = 0
for play in plays:
    for key in ("pre_tasks", "tasks", "post_tasks", "handlers"):
        for task in play.get(key) or []:
            if isinstance(task, dict) and "ignore_errors" not in task:
                task["ignore_errors"] = True
                n += 1
with open(dst, "w") as f:
    f.write("# Généré par scripts/p8-ssg-tolerant.py à partir du playbook SSG officiel (ignore_errors par tâche)\n")
    yaml.safe_dump(plays, f, sort_keys=False, allow_unicode=True, width=200)
print(f"{n} tâches rendues tolérantes -> {dst}")
