"""Live OAuth acceptance check. Tokens stay in memory and are revoked on exit."""
import base64
import hashlib
from http.server import BaseHTTPRequestHandler,HTTPServer
import json
import secrets
from urllib.parse import parse_qs,urlsplit
import httpx

BASE='https://teamsync-api-ui7n.onrender.com'
verifier=secrets.token_urlsafe(48)
challenge=base64.urlsafe_b64encode(hashlib.sha256(verifier.encode()).digest()).decode().rstrip('=')
outcome={}
class Callback(BaseHTTPRequestHandler):
    def log_message(self,*args):pass
    def do_GET(self):
        if urlsplit(self.path).path!='/callback':self.send_error(404);return
        values=parse_qs(urlsplit(self.path).query)
        token=None
        try:
            if values.get('error'):raise RuntimeError(values['error'][0])
            code=values.get('code',[''])[0]
            with httpx.Client(timeout=30) as client:
                response=client.post(BASE+'/api/v1/auth/exchange',json={'code':code,'verifier':verifier,'device':'Live OAuth verification (revoked after test)'})
                if response.status_code!=200:raise RuntimeError('exchange_failed_'+str(response.status_code))
                token=response.json()['access_token']
                profile=client.get(BASE+'/api/v1/me',headers={'Authorization':'Bearer '+token})
                if profile.status_code!=200:raise RuntimeError('profile_failed')
                providers=[r['provider'] for r in profile.json()['identities']]
                outcome.update(ok=True,providers=providers)
                client.post(BASE+'/api/v1/auth/logout',headers={'Authorization':'Bearer '+token})
                token=None
            message='TeamSync: вход проверен. Тестовая сессия закрыта. Можно вернуться в приложение.'
        except Exception as error:
            outcome.update(ok=False,error=type(error).__name__+': '+str(error))
            message='TeamSync: проверка входа не завершилась. Вернитесь в приложение.'
        finally:
            if token:
                try:httpx.post(BASE+'/api/v1/auth/logout',headers={'Authorization':'Bearer '+token},timeout=15)
                except httpx.HTTPError:pass
        payload=message.encode('utf-8')
        self.send_response(200);self.send_header('Content-Type','text/plain; charset=utf-8');self.send_header('Cache-Control','no-store');self.send_header('Content-Length',str(len(payload)));self.end_headers();self.wfile.write(payload)

if __name__=='__main__':
    with HTTPServer(('127.0.0.1',8767),Callback) as server:
        server.timeout=300
        result=httpx.post(BASE+'/api/v1/auth/discord/start',json={'redirect':'http://127.0.0.1:8767/callback','challenge':challenge},timeout=30)
        result.raise_for_status()
        print(result.json()['url'],flush=True)
        server.handle_request()
        print(json.dumps(outcome),flush=True)
        if not outcome.get('ok'):raise SystemExit(1)
