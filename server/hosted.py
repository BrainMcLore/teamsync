"""Render uses its persistent public hostname and an external Neon database."""
import os
import uvicorn

if __name__ == '__main__':
    hostname=os.getenv('RENDER_EXTERNAL_HOSTNAME')
    if not os.getenv('PUBLIC_URL') and hostname:
        os.environ['PUBLIC_URL']='https://'+hostname
    if not os.getenv('DATABASE_URL','').startswith(('postgresql://','postgresql+psycopg://','postgres://')):
        raise RuntimeError('Hosted deployment requires persistent external PostgreSQL')
    uvicorn.run('server.app:create_app',factory=True,host='0.0.0.0',port=int(os.getenv('PORT','8000')),access_log=False)
