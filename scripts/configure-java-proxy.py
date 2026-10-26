"""Refresh Java's proxy route using injected environment settings; never copy credentials."""
import os
from pathlib import Path
from urllib.parse import urlsplit

root = Path(os.environ['GRADLE_USER_HOME'])
root.mkdir(parents=True, exist_ok=True)
path = root / 'gradle.properties'
existing = path.read_text().splitlines() if path.exists() else []
proxy = urlsplit(os.environ.get('HTTPS_PROXY', os.environ.get('https_proxy', '')))
values = {'org.gradle.workers.max': '2'}
if proxy.hostname:
    for protocol in ['http', 'https']:
        values[f'systemProp.{protocol}.proxyHost'] = proxy.hostname
        values[f'systemProp.{protocol}.proxyPort'] = str(proxy.port or 80)
trust = Path('/etc/ssl/certs/java/cacerts')
if trust.is_file(): values['systemProp.javax.net.ssl.trustStore'] = str(trust)
lines = [line for line in existing if line.split('=', 1)[0] not in values]
path.write_text('\n'.join(lines + [f'{k}={v}' for k,v in values.items()]) + '\n')
print('Java network configuration refreshed without credentials')
