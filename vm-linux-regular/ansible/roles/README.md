# Roles

`base` and `first-boot` are the fixed base setup, applied to every VM
this variant deploys — treat them as shared infrastructure, not a place
for a specific application.

## Adding your own service/application/package

1. Create a new role here with the standard layout:
   ```
   roles/<my-service>/
     tasks/main.yml
     defaults/main.yml   (optional)
     handlers/main.yml   (optional)
     templates/, files/  (optional)
   ```
   (`ansible.cfg`'s `roles_path = roles` already makes anything dropped
   here resolvable by name — no extra wiring needed.)
2. List it in `../group_vars/all.yml` (copy from `.example` if you
   haven't yet):
   ```yaml
   service_roles:
     - my-service
   ```
3. Deploy as usual (`../../scripts/deploy.sh`, or the GitLab CI
   `configure` job) — `../playbook.yml` applies every role in
   `service_roles`, in order, after the base roles above.

Multiple services can be listed; they run in the order given.
