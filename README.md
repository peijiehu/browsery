
# Browsery

Browsery is a browser automation test framework built on top of minitest and selenium-webdriver.

### Key Features

 - multiple OS/browser UI automation testing for multiple web apps
 - local/remote test execution(Saucelabs, Browserstack, etc)
 - process level parallelization for simultaneous tests execution
 - page object design supports widgets and sections to minimize code redundancy
 - visual regression - continuous visual comparision, customizable diff percentage
 - test case documents integration - updates test cases on Google sheets after test run


## Prerequisites

#### Firefox

When running locally (with a browser installed on the same machine), all you
need is a supported version of the operating system and browser combination.

For example, to run against Firefox, all you need to do is run tests with the
`firefox` connector (which uses the `firefox` bridge). The connector (and the
bridge behind it) will automatically start the browser in the desired mode.

#### PhantomJS [DEPRECATED]

I no longer recommend installing/using PhantomJS because of its instability.

On Mac OS X, PhantomJS can be installed on [HomeBrew](http://brew.sh). Once
you have HomeBrew installed, and `brew doctor` returns an all okay, you can:

    $ brew install phantomjs

and it should be installed in a minute or so. Before any test are run, you'll
want to start PhantomJS:

    $ phantomjs --webdriver=127.0.0.1:8910

Those parameters are compatible with the `phantomjs` connector supplied in this
project. It can also be run on a different machine; adjust the hostname and
port number parameters as necessary.


## Installation

The simplest way to install it is to use Bundler.

Add Browsery (and any other dependencies) to a Gemfile in your project’s root:

    gem 'browsery'

then install it by running Bundler:

    $ bundle


## Configuration

All configuration files should be placed under the `config/browsery/` directory.
There are configuration files that are required for it to work properly:

* Tests directory structure, in `config/browsery/tests.yml`, which define tests directory's
  relative path and multi-host flag;
* Connector profiles, in `config/browsery/connectors/*.yml`, which define WebDriver
  properties, e.g., Firefox, SauceLabs;
* Environment profiles, in `config/browsery/environments/*.yml`, which define which
  environment tests are going to run against, e.g., QA, production;
* Test Suite definition, in `config/browsery/test_suite.yml`, which defines tags being used
  to mark tests for different suites, eg. :non_regression

A typical config file structure looks like this:

    config/
    └── browsery
        ├── connectors
        │   ├── firefox.yml
        │   ├── phantomjs.yml
        │   └── saucelabs.yml
        ├── data
        │   └── sitemap_states.yml
        ├── environments
        │   ├── baidu_ci.yml
        │   ├── baidu_qa.yml
        │   ├── google_ci.yml
        │   └── google_qa.yml
        ├── test_suite.yml
        └── tests.yml

#### Tests Directory Structure

A Tests Directory Structure file is a regular YAML file, which tells browsery
where to find tests and which tests to load.

A typical config file for this looks like:

    ---
    tests_dir:
        relative_path: 'web_tests'
        multi-host: true

It defines two things:

1. Tests dir relative path(no trailing slash) - same directory where directories
test_cases and page_objects are located, eg. web_tests, xxx/yyyy/tests;
2. multi-host flag: false means test_cases dir is directly under tests_dir,
true means there's one more layer in middle: tests_dir/[hosts]/.

#### Connector Profile

A connector profile is a regular YAML file in a specific directory, which
describes how tests are run.

It should contain, at minimum, the `driver` key, which corresponds to the
browser argument to Selenium::WebDriver.for, which in turn is one of the bridge
types available. As of selenium-webdriver version 2.37.0, the values are:

* `firefox` or `ff` for a local version of Firefox;
* `internet_explorer` or `ie` for a local version of IE (Windows only);
* `chrome` for a local version of Google Chrome;
* `opera` for a local version of Opera;
* `safari` for a local version of Safari;
* `phantomjs` for a local _or_ remote instance of PhantomJS;
* `android` for a local version of the Android emulator on port 8080;
* `iphone` for a local version of the iPhone emulator on port 3001, which has
  been deprecated in favor of a remote hub connection, e.g., to appium.io or
  any such alternative; and
* `remote`, which is the generic remote bridge.

Overall, the bridge types are separated into two: local and remote. Whereas
a local bridge usually takes care of starting an internal server automatically,
a remote bridge is a service that is running a daemon (usually WebDriver Hub)
on a specific address-and-port combination.

For local bridges, the `driver` key is the only key necessary in the profile:

    ---
    driver: 'firefox'

some local bridges may support multiple versions of the same browser, but
you are on your own to set that up.

For remote bridges, you'll usually need the correct `driver` and `hub.url`
keys in the profile, e.g., for a PhantomJS instance running on port 8910
on a remote host:

    ---
    driver: 'phantomjs'
    hub:
        url: 'http://some_address.com:8910'

Of course, this assumes that the remote bridge doesn't require authentication.
For anything else, you'll need to specify the optional `hub.user` and
`hub.pass` keys:

    ---
    driver: 'phantomjs'
    hub:
        url: 'http://some_address.com:8910'
        user: 'username'
        pass: 'password'

A more generic option for remote drivers is the `remote` bridge type. In our
case with PhantomJS, this also works, although your driver's capabilities
may not be set up correctly (and you may run into problems if the website
you are testing attempts to detect touch events, for instance):

    ---
    driver: 'remote'
    hub:
        url: 'http://some_address.com:8910'
        user: 'username'
        pass: 'password'

With any WebDriver Hub, though, this generic remote bridge is exactly what
is required. A hub is an HTTP interface that multiplexes sessions on various
different browsers, machines, and across many versions, through one URL.

One great example is SauceLabs, which has over 30 different combinations of
testing platforms. Unfortunately, in order to configure the multiplexing,
you will need to set up different profiles for each combination. This is where
overrides come in. Let's take, for example, this profile:

    ---
    driver: 'remote'
    hub:
        url: 'http://address.com/wd/hub'
    overrides:
        qateam:
            hub:
                user: 'qateam'
                pass: '1234'
        prodteam:
            hub:
                user: 'prodteam'
                pass: '5678'
        linux_ff20:
            archetype: 'firefox'
            capabilities:
                version: '20.0'
                platform: 'linux'
        linux_chrome31:
            archetype: 'chrome'
            capabilities:
                version: '31'
                platform: 'linux'

Assuming the above profile is placed into `saucelabs.yml`, then when we run
tests with the connector profile `saucelabs:qateam:linux_ff20`, Browsery would
have calculated the following _effective_ profile:

    ---
    driver: 'remote'
    hub:
        url: 'http://address.com/wd/hub'
        user: 'qateam'
        pass: '1234'
    archetype: 'firefox'
    capabilities:
        version: '20.0'
        platform: 'linux'

where the contents of the keys `overrides.qateam` and `overrides.linux_ff20`
are promoted to the root of the profile, and everything else under `overrides`
is removed.

Now, the effective profile has a couple of new keys:

* `archetype` is used to signal to the remote driver what bridge it should use
  in turn to connect to the browser on their end; while
* `capabilities` is a hash, determined by the remote driver, containing any
  number of capability values that the browser should support.

Capabilities are usually determined by the remote webservice, and as such,
refer to the vendor's documentation on the valid values and examples. See also
the top of each connector profile file for a brief description, if any.

Additionally, some drivers also support timeout values under the `timeouts`
key, which can in turn contain the following keys, each taking a value, in
number of seconds:

* `driver` defines the length of time that the bridge will wait for a response
  from the driver;
* `implicit_wait` defines the length of time that the bridge will ask the
  driver to continuously poll the browser for a command, such as finding one or
  more elements on the current page;
* `page_load` defines the amount of time the driver will wait for a page to
  load before giving up and returning an error; and
* `script_timeout` defines the amount of time the driver will allow JavaScript
  to be executed on a specific page before halting execution and returning an
  error to the bridge.

An example of the `timeouts`:

    ---
    driver: 'phantomjs'
    hub:
        url: 'http://some_address.com:8910'
    timeouts:
        driver: 90
        implicit_wait: 90

It is important to note that not all drivers support all timesouts. The
`timeouts.driver` and `timeouts.implicit_wait` are the two safest to rely upon.
In general, `timeouts.driver` should be the longest of the timeouts, if
specified, because otherwise, the page could timeout after the driver does,
causing a false negative in the test (and often a cryptic error message).


#### Environment Profile

An environment profile is a regular YAML file in a specific directory, which
describes against what environment tests are run.

Only one key is required: `root`, which points to the root URL for the
environment:

    ---
    root: 'http://www.env.host_address.com'

Environment variable as value of `root` is also supported, eg.

    ---
    root: <%= ENV['DYNAMIC_APP_URL'] %>

#### Test Suite

A typical test suite configuration file looks like this:

    ----
    regression:
        tag_to_exclude: :non_regression

- Regression

    - Integration
    - Non-integration

- Non-regression

    - Automated test that is not testing (user) features.
    Examples: link checker(mainly for sitemap), events(tracking, logging)

When adding a new test, it'll be part of regression suite by default.
To make it part of integration in addition to regression, add tag :integration;
To exclude it from regression, add tag :non_regression (by default),
or find the appropriate tag_to_exclude in config/browsery/test_suite.yml

#### Google Sheets

As of v1.1, browsery now supports automatically updating test plans stored in Google Sheets.

To make this work, you will first need to set up OAuth2 access by setting up a project in the Google
Developers Console and obtaining a client ID and client Secret.
More information can be found here: https://developers.google.com/identity/protocols/OAuth2

Place your client ID and client Secret in a new file at the following location:
config/browsery/google_drive_config.json
(See config/browsery/google_drive_config.sample.json for an example)

At the end of each test, you will need to place the following line:
Browsery.google_sheets.update_cells('Test_Result', 'Test_ID') if Browsery.settings.google_sheets?
- Replace Test_Result with the text that you would like to be printed to the sheet after your test
  has passed
- Replace Test_ID with the unique identifier for the test - this must match what is in your sheet

In your Google Sheets spreadsheet, add a column with 'Automation Serial Key' in the top cell
For each test, add the unique identifier that corresponds to Test_ID above in this column for the
applicable row

When running a test, use the -g or --google_sheets parameter followed by the ID of your spreadheet.
Ex: -g 5xFshUc5kdXcHwKSIE4idIKOW-jdk5c5x5ed4XkhX4kl
You can find the ID in the URL for your google sheet spreadsheet before the '/edit':
https://docs.google.com/spreadsheets/d/5xFshUc5kdXcHwKSIE4idIKOW-jdk5c5x5ed4XkhX4kl/edit#gid=198261705

The first time you run a test with a google sheet update, you will be prompted to go to a URL and
enter the string found there. After this, there will be additional information added to your
google_drive_config.json that will include a refresh token - if the refresh token expires, you will
need to repeat this step.

## Executing Tests

See the _Configuration_ section above to have the minimum setup before running tests.

To run test headlessly on default environment(stg), set connector to GhostDriver,
which is Phantomjs's implementation of webdriver protocal, run:

    $ bundle exec browsery --connector=phantomjs

To override the connector to your local browser, and to override environment,
use these options:

    $ bundle exec browsery --connector=firefox --env=qa

which will use `config/browsery/connectors/firefox.yml` and `config/browsery/environments/qa.yml`
as the profiles.

Some profiles may contain a section named `overrides`, for example, to support
multiple browsers in a remote execution environment like SauceLabs. Such
profiles can be used like this:

    $ bundle exec browsery --connector=saucelabs:linux_ff20 --env=google_qa

which will use the `linux_ff20` override in the `saucelabs` connector profile,
and run tests against the `google_qa` environment. Multiple overrides may be specified
one after the other, after the profile name, and always separated by colons,
for example:

    $ bundle exec browsery -c saucelabs:linux_ff20:qateam:notimeouts -e google_qa

To make a specific connector or environment profile always be the default on
your machine or shell session, set the `BROWSERY_CONNECTOR` or `BROWSERY_ENV`
environment variables respectively. For example, you can add the following to
your shell profile (`.bash_profile` for bash or `.zlogin` for zsh):

    export BROWSERY_CONNECTOR=firefox
    export BROWSERY_ENV=google_qa

Refer to the _Configuration_ section above for advanced use cases, and refer
to `browsery -h` for a complete list of command line options.


#### Running a Subset of Tests

Assuming you have a test in `Browsery::TestCases::Search` that is defined as:

    test :search_zip, tags: [:homepage, :srp, :zip, :critical] do
        # Assertions go here
    end

then you have a couple of different options to run it. The most straight-
forward case is to run all test cases:

    $ bundle exec browsery

As a second option, you can run only that specific test case. For that, you'll
need to know the name of the test case, and add `test_` in front of it. In the
example above, the name is `search_zip`, so it can be run like so:

    $ bundle exec browsery -n test_search_zip

As a third option, you can run any test case whose name contains the word
"search" in it:

    $ bundle exec browsery -n /search/

It should be noted that this form supports regular expressions so that:

    $ bundle exec browsery -n '/search_\d{5}/'

will run all test cases with the word `search_` followed by five digits. Keep
in mind that _special characters_ such as backslashes and curly braces must
either be escaped, or quoted.

The fourth option is to run test cases that match one or more tags. To run all
test cases with the tag `:srp`, we can:

    $ bundle exec browsery -t srp

The `-t` option is powerful, because it supports multiple tags. To run all test
cases tagged with `:homepage` *and* `:srp`, use:

    $ bundle exec browsery -t homepage,srp

To run all test cases tagged with `:homepage` or tagged with `:srp` (or both):

    $ bundle exec browsery -t homepage -t srp

And of course, the combination also works:

    $ bundle exec browsery -t srp,submarket -t srp,zip

But what about tests you want NOT to run, that are slow or test functionality
you know is broken? If your preferences correspond to a certain tag (say,
:slow), you can negate that tag by prefixing it with '!', which may need to be
quoted or escaped in some shells/contexts.

    $ bundle exec browsery -t 'mygoogle,!slow' # skip slow mygoogle tests
    $ bundle exec browsery -t mygoogle,\!slow  # likewise
    $ bundle exec browsery -t \!search       # run all non-search tests

Note, every test has a tag added automatically during run time, the tag is formatted
by removing all underscores from name of a class, and prefixing it with "class_".
For example, to run all tests in sign_in.rb,

    $ bundle exec browsery -t class_signin

#### Debug output

It's not good style to clutter your code with puts messages. Instead, use the
handy built-in logger facility defined in Browsery::Utils::Loggable, accessible
through the 'logger' method in TestCase and PageObject objects, like so:

  test :my_fancy_test, tags: [:fancy] do
    self.logger.debug "Let's get fancy!"
  end

The logger prints messages to logs/browsery.log. You won't see debug messages
there by default; for that you need to go beyond --verbose and add an extra 'v'
to your flags:

    $ bundle exec browsery -t fancy -vv

#### TAP

For more info on TAP (Test Anything Protocol), see also:
http://www.testanything.org/

The option in browsery is:

  --tapy  Use TapY reporter.
  --tapj  Use TapJ reporter.

The TapY is YAML, and the TapJ is JSON output.

#### TAPOUT

TAPOUT gets test result from TapY or TapJ, then output result using a reporter by your choice.
To see a list of options and reporters from gem TAPOUT,

    $ tapout --help

To use our custom reporter, FancyTapReporter,

    $ bundle exec browsery --tapy | tapout -r $(bundle show browsery)/lib/tapout/custom_reporters/fancy_tap_reporter.rb fancytap

To make it presentable to jenkins or other webpage, supress color/highlight codes,

    $ bundle exec browsery --tapy | tapout --no-color -r $(bundle show browsery)/lib/tapout/custom_reporters/fancy_tap_reporter.rb fancytap


## Test Cases

Test cases should be added as a class under `Browsery::TestCases` (plural), and
inherit from the class `Browsery::TestCase` (singular).

The setup and teardown methods should be added as class attributes:

    module Browsery
        module TestCases
            class LeaseReport < TestCase

                setup do
                    # Contents of the setup
                end

                teardown do
                    # Contents of the teardown
                end

            end
        end
    end

This approach is used in order to allow us to compose our objects correctly and
allow the inheritance chain to always be respected. The alternative to this is
the normal `setup` and `teardown` methods, but a `super()` must always be called
at the beginning and at the end of each, respectively. By using class attributes,
we don't need to do anything else special.

Similarly, test cases should be provided as an attribute on the class:

    class LeaseReport # continuing from the example above, it already inherits

        test :arbitrary_name, tags: [:foo, :bar] do
            # Contents of test here, with assert_* calls
        end

    end

See {Running a Subset of Tests} for information on the `tags` option.


## Page Objects

Parts of a page should be added under `Browsery::PageObjects::Components`, and
overlays should be added under `Browsery::PageObjects::Overlay`.

Because of WebDriver's asynchronous nature, the order of operations is never
guaranteed. When casting a page to another page, the `cast` call _should_
happen right after the action that causes the page to change. For example, if
clicking on a link causes the page to move to another page, the cast should
happen after the click, and before anything else:

    def some_action!
        @driver.find_element(:id, 'main-link').click
        # There should be nothing in between these two lines; in fact, the
        # cast should be the last line of the method
        cast(:new_page)
    end

Page object methods that return a different page must end in `!`, signifying
that is returns a different page object, thus invalidating the current page
object. Page object invalidation is handled automatically through the use of
ruby object freezing.

#### Overlay

An Overlay represents a portion (an element) of a page that can be repeated
Multiple times across many pages.  But only appear once per page at a time.
Some examples of overlays include:
  -Password
  -Hotlead
Overlays will be called via Includes on the page object, when accessing overlays
its best to return the current page as an object, ie:
      #Check Availability link on srp,
      # Return +HotLead+s representing hotlead overlay on
      # the SRP.
      def check_availability!
        @driver.find_element(*LINK_CHECKAVAILABILITY).click
        cast(:search)
      end
Overlays are technically not new pages, and should be differentiated from actual pages.

#### Widgets

A widget represents a portion (an element) of a page that is repeated
or reproduced multiple times, either on the same page, or across multiple
page objects or page modules.


## Best Practice

* Always use local variables, unless _absolutely_ necessary, then use instance
  variables.  Avoid constants and class variables unless you know what you're
  doing. Never use global variables.
* To keep track of configuration settings, see the _CONFIGURATION_ section above.
* If you need to keep track of global state, you're doing it wrong. If you need
  configuration settings, see previous bulletpoint.
* Comment your code. All methods must be commented, but you shouldn't add a
  comment every line.
* Always explicitly open your modules and class definitions, e.g., use:

        module A
            module B
                class C
                    # code goes here
                end
            end
        end

  instead of:

        class A::B::C
            # code goes here
        end

  because the latter will not properly resolve class names. See [this blog
  post](http://cirw.in/blog/constant-lookup.html) for an explanation.  There
  are other alternatives, such as `ActiveSupport::Dependencies`, which brings
  [other caveats](http://urbanautomaton.com/blog/2013/08/27/rails-autoloading-hell/)
  to the table.
* Indent all Ruby code using 2 spaces.
* Page object methods that return a different page _must_ end in a `!`.


## Troubleshooting

**I receive a `Net::ReadTimeout` when running my tests.**

The cause for `Net::ReadTimeout` is usually one of two things:

* a temporary error caused by one or more external elements on the page that
  blocks the browser from loading the page in its entirety; or
* a permanent error caused by the driver timeout being too low. See connector
  profiles and the `timeouts.driver` key.


**I receive a `401`, `404` or other HTTP errors before even running my tests.**

HTTP status codes can be returned by the browser, or by the driver. If the
browser is returning those codes, then it is outside the scope of this page.

If, however, the driver is returning those codes, then there are several
possible reasons:

* on a 400, the bridge command is most likely sending an incomplete request,
  and could mean that the bridge doesn't support certain features of the
  driver;
* on a 401, you are most likely not using the correct username and password for
  the hub URL (the `hub.user` and `hub.pass` keys);
* on a 404, you are most likely using an invalid command, possibly a command
  that is not supported by the remote hub, or by the browser on the remote hub;
* on a 405, you are using a custom command incorrectly, e.g., using a GET to
  the hub, rather than a POST;
* on a 501, the bridge (the ruby side) uses too new of a version compared to
  the driver or browser, and a browser upgrade is usually recommended, or if
  necessary, adjust the list of capabilities.

In addition to regular HTTP status codes, the bridge also understands the
standardized Response Status Codes as defined in the [Selenium WebDriver JSON
Wire Protocol](https://code.google.com/p/selenium/wiki/JsonWireProtocol).


**I receive a `StaleElementReferenceError` (or similar sounding name)**
**intermittently when running one or more tests.**

A stale element reference is a reference to an element that is no longer active
on the page. This usually happens when you find an element on a page, go a
different page (either by `get()`ing a new URL or by interacting with an
element), and then try to perform actions against the aforementioned element on
the page.

## Contributing

1. Fork it
2. Create your feature branch `git checkout -b my-new-feature`
3. Commit your changes `git commit -am 'Add some feature'`
4. Push to the branch `git push origin my-new-feature`
5. Create new Pull Request

## License

Browsery is released under the MIT License. See the bundled LICENSE file for
details.
