;<?php http_response_code(403); /*
; config file for PrivateBin
;
; An explanation of each setting can be find online at https://github.com/PrivateBin/PrivateBin/wiki/Configuration.

[main]
; (optional) set a project name to be displayed on the website
; name = "PrivateBin"

; The full URL, with the domain name and directories that point to the
; PrivateBin files, including an ending slash (/). This URL is essential to
; allow Opengraph images to be displayed on social networks.
; basepath = "https://privatebin.example.com/"

; enable or disable the discussion feature, defaults to true
discussion = true

; preselect the discussion feature, defaults to false
opendiscussion = false

; enable or disable the password feature, defaults to true
password = true

; enable or disable the file upload feature, defaults to false
fileupload = false

; preselect the burn-after-reading feature, defaults to false
burnafterreadingselected = false

; which display mode to preselect by default, defaults to "plaintext"
; make sure the value exists in [formatter_options]
defaultformatter = "plaintext"

; size limit per paste or comment in bytes, defaults to 10 Mebibytes
sizelimit = 10485760

; template to include, default is "bootstrap" (tpl/bootstrap.php)
template = "bootstrap"

; by default PrivateBin will guess the visitors language based on the browsers
; settings. Optionally you can enable the language selection menu, which uses
; a session cookie to store the choice until the browser is closed.
languageselection = false

[expire]
; expire value that is selected per default
; make sure the value exists in [expire_options]
default = "1week"

[expire_options]
; Set each one of these to the number of seconds in the expiration period,
; or 0 if it should never expire
5min = 300
10min = 600
1hour = 3600
1day = 86400
1week = 604800
; Well this is not *exactly* one month, it's 30 days:
1month = 2592000
1year = 31536000
never = 0

[formatter_options]
; Set available formatters, their order and their labels
plaintext = "Plain Text"
syntaxhighlighting = "Source Code"
markdown = "Markdown"

[traffic]
; time limit between calls from the same IP address in seconds
; Set this to 0 to disable rate limiting.
limit = 10

[purge]
; minimum time limit between two purgings of expired pastes, it is only
; triggered when pastes are created
; Set this to 0 to run a purge every time a paste is created.
limit = 300

; maximum amount of expired pastes to delete in one purge
; Set this to 0 to disable purging. Set it higher, if you are running a large
; site
batchsize = 10

[model]
; name of data model class to load and directory for storage
; the default model "Filesystem" stores everything in the filesystem
class = Filesystem
[model_options]
dir = PATH "data"
