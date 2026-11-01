# Integrations

| Component | Implementation and boundary |
| --- | --- |
| Steam / Discord | Server-mediated identity and team membership. Discord requests the basic profile. Provider secrets remain on the server. Broader live Steam acceptance remains pending. |
| HLTV | Windows catalog/download companion with an isolated native WebView2 verification window when needed. Availability depends on the external site/CDN; browser sessions are not extracted. |
| Demo parser | Separate demoparser2 worker; DEM, ZIP and RAR inputs with path and size checks. Dependencies are pinned in `worker`. |
| CS2 | Windows launch integration requires an installed game. Real playback acceptance remains a separate check. |
| Bootcamp | Local Windows CS2/TeamSpeak downloads and practice/PUG controls. Plugin versions, original URLs and hashes are pinned in the worker installer. Remote agent control remains planned. |
| Media | Own PNG/JPEG/MP4 materials stored through the team API. Third-party video links open the original source. |
| PDF | Native PDF generation using bundled fonts; tactic snapshots and round plans. |
| Secure storage | OS credential storage and native callback handling. The vendored Windows adapter retains its upstream license. |

Map sources, revisions and ownership are recorded in [attribution](../client/assets/maps/ATTRIBUTION.txt) and [manifest](../client/assets/maps/manifest.json). Dependencies retain their original licenses. API configuration is described in [deployment](deployment.md); real-world validation limits are in [acceptance](acceptance.md).
