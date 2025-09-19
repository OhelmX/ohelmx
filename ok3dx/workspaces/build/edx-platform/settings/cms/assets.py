"""
Bare minimum settings for collecting production assets.
"""
from ..common import *
from openedx.core.lib.derived import derive_settings

ENABLE_COMPREHENSIVE_THEMING = True

SECRET_KEY = 'secret'
XQUEUE_INTERFACE = {
    'django_auth': None,
    'url': None,
}
DATABASES = {
    "default": {},
}
# Dummy value required for the static asset build steps to run,
# but it has no impact on the output produced by those steps.
LMS_ROOT_URL = "https://lms.local"


javascript_files = ['base_application', 'application', 'certificates_wv']
dark_theme_filepath = ['indigo/js/dark-theme.js']

for filename in javascript_files:
    if filename in PIPELINE['JAVASCRIPT']:
        PIPELINE['JAVASCRIPT'][filename]['source_filenames'] += dark_theme_filepath

WEBPACK_LOADER['DEFAULT']['STATS_FILE'] = path(STATIC_ROOT) / "webpack-stats.json"

derive_settings(__name__)