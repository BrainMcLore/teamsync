from pathlib import Path
import pytest
import hltv_catalog as catalog
from demo_worker import ImportFailure

def test_managed_engine_is_used_for_source_challenge_only(tmp_path, monkeypatch):
    called=[]
    def blocked(*args):raise ImportFailure('source_blocked')
    monkeypatch.setattr(catalog,'download_demo_http',blocked)
    monkeypatch.setattr(catalog,'managed_download',lambda *args:called.append(args) or args[1])
    target=tmp_path/'download.tmp'
    assert catalog.download_demo('https://www.hltv.org/download/demo/42',target,100)==target
    assert len(called)==1

def test_regular_download_does_not_start_managed_engine(tmp_path, monkeypatch):
    target=tmp_path/'download.tmp'
    monkeypatch.setattr(catalog,'download_demo_http',lambda *args:target)
    monkeypatch.setattr(catalog,'managed_download',lambda *args:pytest.fail('unnecessary engine'))
    assert catalog.download_demo('url',target,100)==target

def test_cancel_and_size_errors_do_not_retry_as_browser_download(tmp_path, monkeypatch):
    def bad(*args):raise ImportFailure('file_too_large')
    monkeypatch.setattr(catalog,'download_demo_http',bad)
    monkeypatch.setattr(catalog,'managed_download',lambda *args:pytest.fail('must preserve limit'))
    with pytest.raises(ImportFailure,match='file_too_large'):catalog.download_demo('url',tmp_path/'download.tmp',100)


def test_catalog_uses_managed_session_only_for_blocked_source(tmp_path, monkeypatch):
    def blocked(*args): raise catalog.CatalogError('source_blocked')
    monkeypatch.setattr(catalog, 'html_http', blocked)
    monkeypatch.setattr(catalog, 'managed_html', lambda *args: '<html>real page</html>')
    assert catalog.html('https://www.hltv.org/results', tmp_path) == '<html>real page</html>'


def test_catalog_rate_limit_never_retries_in_managed_session(tmp_path, monkeypatch):
    def limited(*args): raise catalog.CatalogError('hltv_rate_limited')
    monkeypatch.setattr(catalog, 'html_http', limited)
    monkeypatch.setattr(catalog, 'managed_html', lambda *args: pytest.fail('must respect cooldown'))
    with pytest.raises(catalog.CatalogError, match='hltv_rate_limited'):
        catalog.html('https://www.hltv.org/results', tmp_path)
