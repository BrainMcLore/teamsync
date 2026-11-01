import uvicorn

if __name__=='__main__':
    # Callback query strings contain one-time codes; access logs must be disabled.
    uvicorn.run('server.app:create_app',factory=True,host='127.0.0.1',port=8000,access_log=False)
