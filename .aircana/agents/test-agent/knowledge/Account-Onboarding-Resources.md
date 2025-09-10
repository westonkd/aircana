## Account Readiness

Want to know if an account is a candidate for starting redirects to IDM? It’s pretty easy!

**Shortcut:** If you are looking for Google SAML-only accounts, [this list](https://docs.google.com/spreadsheets/d/1lSKY5zTDwI5OC1ES08unM9LckabyPzm-4G_ejrA7B9I/edit?usp=sharing) has already had features validated. Just make sure your account is listed there 🎉

**Manual Check**

1. Identify the ULR of the account you’d like to check. For example: `fourcounty.instructure.com`

2. If you’ve not already signed in to Canvas site admin, do so by visiting [https://www.siteadmin.instsructure.com](https://www.siteadmin.instsructure.com) and signing in with Okta

3. Navigate to the account you’d like to check: [<u>fourcounty.instructure.com</u>](http://fourcounty.instructure.com)

4. Add `/api/v1/instructure_identity/validate_features` to the end of your URL. Example: `fourcounty.instructure.com/api/v1/instructure_identity/validate_features`

5. If things look good, you’ll see a message like `Validated features and configuration for 178240000000000001 are supported.` Otherwise, a detailed error message will be gibven.

## Dynamic Rate Adjustment

Canvas enables the adjustment of the rate at which a specific authentication provider utilizes Instructure Identity for login purposes.

Automation has been implemented to dynamically either increment or decrement this redirect rate.

### Increment

A [DataDog monitor](https://app.datadoghq.com/monitors/174038481) has been established to trigger every 24 hours. One of the targets for this trigger is the webhook integration, which sends a POST request to an endpoint in Canvas to increment the Instructure Identity rate.

The increment endpoint in Canvas is designed to exponentially ramp the Instructure Identity rate from 0% to 100% over a period of 30 days:

<ac:image ac:align="center" ac:layout="center" ac:original-height="71" ac:original-width="211" ac:custom-width="true" ac:width="211"><ri:attachment ri:filename="image-20250609-151735.png" ri:version-at-save="1"></ri:attachment></ac:image>

For a visual representation of this equation, check out [this link](https://www.desmos.com/calculator/0vzgwkivqi). The X-axis represents the number of days since onboarding for a given authentication provider began, while the Y-axis indicates the Instructure Identity rate for that provider.

Importantly, a new monitor for each auth type needs to be created in this style once an authentication provider type is supported.

If a given account has no login attempts in the last 24 hours, the increment for that 24 hour period is skipped.

### Monitoring

The history of both increment and decrement operations is visible in [this DataDog timeseries](https://app.datadoghq.com/dashboard/xxa-jiv-eyp/canvas-identity-onboarding?fromUser=true&fullscreen_end_ts=1749482966605&fullscreen_paused=false&fullscreen_refresh_mode=sliding&fullscreen_section=overview&fullscreen_start_ts=1749396566605&fullscreen_widget=3313737158798124&refresh_mode=paused&from_ts=1748759695201&to_ts=1749460167062&live=false).

## Configuration

Most configuration for Instructure Identity lives in the `PluginSetting` with the same name.

PluginSettings are configured per region/environment with the following exceptions:

| 

**Plugin Context**

 | 

**Notes**

 |
| --- | --- |
| 

[eastonvalleycsd.instructure.com/plugins/instructure\_identity](http://eastonvalleycsd.instructure.com/plugins/instructure_identity)

 | 

Modified “ticks to full migration” for early access

 |
| 

[bgdhs.instructure.com/plugins/instructure\_identity](http://bgdhs.instructure.com/plugins/instructure_identity)

 | 

Modified “ticks to full migration” for early access

 |
| 

[oakfield.instructure.com/plugins/instructure\_identity](http://oakfield.instructure.com/plugins/instructure_identity)

 | 

Modified “ticks to full migration” for early access

 |
| 

[cushingps.instructure.com/plugins/instructure\_identity](http://cushingps.instructure.com/plugins/instructure_identity)

 | 

Modified “ticks to full migration” for early access

 |
| 

[columbusisd.instructure.com/plugins/instructure\_identity](http://columbusisd.instructure.com/plugins/instructure_identity)

 | 

Modified “ticks to full migration” for early access

 |
| 

[nlsd.instructure.com/plugins/instructure\_identity](http://nlsd.instructure.com/plugins/instructure_identity)

 | 

Modified “ticks to full migration” for early access

 |
| 

[antigoschools.instructure.com/plugins/instructure\_identity](http://antigoschools.instructure.com/plugins/instructure_identity)

 | 

Modified “ticks to full migration” for early access

 |
| 

[freemontcommunityschools.instructure.com/plugins/instructure\_identity](http://freemontcommunityschools.instructure.com/plugins/instructure_identity)

 | 

Modified “ticks to full migration” for early access

 |

## Links

| 

**Description**

 | 

**Link**

 |
| --- | --- |
| 

Canvas Auth Type Increment Monitor

 | 

[https://app.datadoghq.com/monitors/174038481](https://app.datadoghq.com/monitors/174038481) (should always be in an alert state)

 |
| 

Canvas Decrement Monitor

 | 

[https://app.datadoghq.com/monitors/170997408](https://app.datadoghq.com/monitors/170997408)

 |
| 

Onboarding Monitoring (The `Dynamic Rate Adjustment` timeseries shows when rates are adjusted)

 | 

[https://app.datadoghq.com/dashboard/xxa-jiv-eyp/canvas-identity-onboarding](https://app.datadoghq.com/dashboard/xxa-jiv-eyp/canvas-identity-onboarding)

 |

