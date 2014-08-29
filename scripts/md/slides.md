title: Presenters
class: big
build_lists: true

<!---

  eZ Summercamp 2014 Talk

  Learnings from Real eZ Publish 5 Projects

  (c) 2014 Ekkehard Dörre, Donat Fritschy

-->

* <strong>Donat</strong> is owner of Webmanufaktur, a full service web agency in Switzerland. He works as projects manager, software architect and developer and likes thinking outside of the box. In the last year he has been involved in major eZ 5 projects.
* <strong>Ekke</strong> is a consultant with deep knowledge in eZ Publish 4 and 5, eZ Find / Apache Solr and with a faible for coming cutting edge web technologies. He is one of the organizers of the PHP Unconference since seven years.
* Members of CJW Network

---

title: Learnings from Real eZ Publish 5 Projects
class: big
build_lists: true

- Last year we have presented our Cookbok...
- ... today you get a Ratatouille ;-)

- Let's share the experiences you and we made in the last year!

---

title: Agenda
class: big
build_lists: true

Things we would like to discuss:

- Good Practice
- ez View Cache vs. HTTP Cache
- Debugging
- Pitfalls
- MultiSite Setup

---

title: Good Practice
subtitle:
class: segue dark nobackground

---

title: Team up with a Symfony Crack

- To be honest: as eZ 4 developers, we are complete novices in eZ 5
- It's easier for a Smyfony Crack to learn eZ than other way round
- Symfony community is hungry for a CMS, so watch out for new competition

---

title: Think in MVC

- A radical different thinking
- eZ 4 mangeled all together in the TPL -&gt; the view implemented the logic (fetch)
- Symfony enforces a clean separation, from routing to the controller to the rendering of the view

---

title: Think in Bundles

- Split your application in different bundles (site specific, functional, ...)
- Reuse your code: create and maintain a Base Bundle with general functions

Creating bundles is easy, don't work in the DemoBundle ;-)

<pre class="prettyprint" data-lang="bash">
$ php ezpublish/console generate:bundle
</pr>

---

title: Organize your config files

- The standard eZ installation is a mess...
- ... and the DemoBundle only slowly becoming a source of good practice

Our approach

- keep config in `ezpublish/config` as general as possible
- it should merely decribe your environment, not the application
- move all site/function specific settings to the bundle

---

title: Keep ezpublish.yml small

`ezpublish/config/ezpublish.yml`

<pre class="prettyprint" data-lang="yml">
imports:
    - {resource: "@CjwExampleBundle/Resources/config/ezpublish.yml"}
</pre>

Keep these sections:

- doctrine (Database)
- ezpublish (Siteaccess Matching, Siteaccesses, Languages, Caching)
- stash

Can even be shorter - get inspiration from <https://github.com/lolautruche/metalfrance>

*Note: prepending configuration does not work well with parameters*

---

title: Config Files in Bundle

We keep them in a separate directory and name them as in good old eZ...

<pre>
ExampleBundle
&#8990; Resources
  &#8990; config
    &#8990; ezpublish
        image.yml
        override.yml
      ezpublish.yml
      parameters.yml
      routing.yml
      services.yml
</pre>

---

title: Controllers

After several tries, we ended up with...

- Basically one controller per full view
- Separate controllers for navigation etc.
- Retrieve all needed data (location, children, ...)
- Prepare the data for easy processing in the templates
- Consider caching (TTL, X-Location Header)

---

title: Ways to Fetch Content

- SearchService::findContent()
- SearchService::findLocations()

- LocationService::loadLocationChildren()

- Legacy fetch functions

---

title: SearchService::findContent()
build_lists: true

The only `SearchService` function you will find in `DemoBundle`

- returns full `content` objects with ALL attributes in ALL languages
- scales very badly
- no `asObjects` flag as in eZ 4

- fetching a content tree with 116 locations took 30 seconds
- most of the time is spent in manipulating the SQL result in PHP
- Another test: 24 hits, PHP array 44'880 rows with 39 elements each, highly redundant

<http://share.ez.no/blogs/donat-fritschy/searchservice-performance>

---

title: SearchService::findLocations()
build_lists: true

**Available from 2014.05 / 5.3 only**

Roughly equivalent to good old `fetch( 'content', 'list' )`

- returns `location` objects with `contentInfo` only
- fetching a content tree with 116 locations took &lt; 1 second

---

title: LocationService::loadLocationChildren()

&laquo;Think of `LocationService::loadLocationChildren()` as primarily intended for administration interface.&raquo;

&laquo;If what it offers suits you for the frontend as well, great, but otherwise you will have to use SearchService. In other words, this method will not get filtering capabilities.&raquo;

*(From a discussion with Petar)*

<http://www.netgenlabs.com/Blog/Fetching-content-in-eZ-Publish-5-using-Search-service>

---

title: Legacy Fetch Functions
class: smaller

<pre class="prettyprint" data-lang="php">
use eZFunctionHandler;
...
$mySearchResults = $this->getLegacyKernel()->runCallback(
    function () use ( $searchPhrase, $sort, $contentTypeIdenfiers )
    {
        // eZFunctionHandler::execute is the equivalent for a legacy template fetch function
        // The following is the same than fetch( 'ezfind', 'search', hash(...) )
        return eZFunctionHandler::execute(
            'ezfind',
            'search',
            array(
                'query'     => $searchPhrase,
                'sort_by'   => $sort,
                'class_id'  => $contentTypeIdenfiers
            )
        );
    }
);
</pre>

---

title: TWIG Templates

- A generalized full and line view template for the easy stuff
- And again, basically one template per full view


How to hande children (sub items)?

- render directly in the template - the data is usally already there
- use `{{ render( controller( 'ez_content:viewLocation', {'locationId': child.id, 'viewType': 'line'} )) }}`

When to use ESI?

- nice concept, but quite a big overhead
- better suited for larger chunks

---

title: How to organize Templates?

The Symfony way...

<pre>
views
&#8990; Customer
    CustomerDetail.html.twig
&#8990; Product
</pre>

The classic eZ way...

<pre>
views
&#8990; full
    customer.html.twig
&#8990; line
</pre>

Two approaches, both valid. Follow your taste.

---

title: eZ View Cache vs. HTTP Caching
subtitle:
class: segue dark nobackground

---

title: eZ View Caching

When the pagelayout is rendered, the `{$module_result.content}` part will be replaced with the actual output. If view caching is enabled, the entire result of the module will be cached. This means that the contents of the "module_result" variable will be put into a cache file (...)

When a new version (...) of an object is published, the system will automatically clear the view cache for the following items:

* All published nodes of the object
* The parent nodes
* Related nodes (keywords, object relations)

<https://doc.ez.no/eZ-Publish/Technical-manual/4.x/Features/View-caching>

---

title: HTTP Expiration and Validation
build_lists: true

The HTTP specification defines two caching models:

* With the **expiration model**, you simply specify how long a response should be considered "fresh" by including a Cache-Control and/or an Expires header. Caches that understand expiration will not make the same request until the cached version reaches its expiration time and becomes "stale";
* When pages are really dynamic (i.e. their representation changes often), the **validation model** is often necessary. With this model, the cache stores the response, but asks the server on each request whether or not the cached response is still valid. The application uses a unique response identifier (the Etag header) and/or a timestamp (the Last-Modified header) to check if the page has changed since being cached.

<http://symfony.com/doc/current/book/http_cache.html>

---

title: In Short (and much simplified...)

eZ View Cache caches **content** and **content fragements**

* Standard TTL is 2 hours
* Is purged on content modifications (with smart cache clearing rules)

Symfony's HTTP Cache caches **requests**

* eZ uses Expiration model by default
* Standard TTL is 60 seconds (86400 for tree menu!)
* Symfony Cache is purged from backend, **but only for ONE location**

Let's dive in a bit deeper...

---

title: ez 4 Cache Directives

Code from `ezpublish_legacy/kernel/private/classes/ezpkernelweb.php`

<pre class="prettyprint" data-lang="php">
// send header information
foreach (
    eZHTTPHeader::headerOverrideArray( $this->uri ) +
    array(
        <b>'Expires' => 'Mon, 26 Jul 1997 05:00:00 GMT',
        'Last-Modified' => gmdate( 'D, d M Y H:i:s' ) . ' GMT',
        'Cache-Control' => 'no-cache, must-revalidate',
        'Pragma' => 'no-cache',</b>
        ...
      ) as $key => $value
)
{
    header( $key . ': ' . $value );
}
</pre>

**This guarantees that every request is handled by eZ**

---

title: eZ 5 Cache Directives

Code from `vendor/ezsystems/demobundle/EzSystems/DemoBundle/Controller/DemoController.php`

<pre class="prettyprint" data-lang="php">
// Setting HTTP cache for the response to be public and with a TTL of 1 day.
$response = new Response;
$response->setPublic();
$response->setSharedMaxAge( 86400 );
// Menu will expire when top location cache expires.
$response->headers->set( 'X-Location-Id', $rootLocationId );
// Menu might vary depending on user permissions, so make the cache vary on the user hash.
$response->setVary( 'X-User-Hash' );
</pre>

**This effectively sets the Response free, out of the reach of eZ**

---

title: Emulating eZ 4 Cache behaviour in eZ 5

This patch to `index.php` disables client and proxy caching without sacrifying the benefits of the Symfony HTTP cache. Use at own risk!

<pre class="prettyprint" data-lang="php">
$response = $kernel->handle( $request );
<b>
// Emulate eZ 4 cache control
$response->headers->set( 'Cache-Control', 'no-cache, must-revalidate' );
</b>
$response->send();
$kernel->terminate( $request, $response );
</pre>

---

title: Cache Recommendations

* Read the specifications
* Use Shared Caches with caution
* Set TTL values low enough
* Cave: `setTtl()` vs. `setClientTtl`
* For higher traffic sites, use Varnish

* <http://tools.ietf.org/html/rfc2616#page-74>
* <https://www.mnot.net/cache_docs/>

---

title: Debugging
subtitle: Coping with blank screens
class: segue dark nobackground

---

title: Blank screen, "503 Service not available"

* PHP errors (Syntax error, Memory, Outdated Autoloads, ...)
* Configuration errors (DB connection, ...)

* Switch to DEV mode for better debugging
* Check the log files
<pre>
    Apache/PHP Log
    ezpublish/logs/&lt;env&gt;.log
    ezpublish_legacy/var/log/\*
    ezpublish_legacy/var/&lt;siteaccess&gt;/log/\*
</pre>
* Check write permissions on log files!

---

title: TwigBundle:Exception:error500.html.twig

* NEVER a Twig error!
* Caused by response 500 "Internal Server Error" and missing error template

* Checks as before

---

title: Twig Exception: Invalid variation "&lt;variation&gt;"

Caused by problems when accessing images

* Check if the file exists
* Check permissions on `ezpublish_legacy/var/<siteaccess>/storage`
* Check log files
* Clear cache

---

title: Class 'ezxFormToken' not found

* Usually found with fresh installations involving legacy extensions
* Regenerate Autoloads

<pre class="prettyprint" data-lang="bash">
$ cd ezpublish_legacy
$ php bin/php/ezpgenerateautoloads.php -e -p
</pre>

---

title: Pitfalls
subtitle: Avoid the traps...
class: segue dark nobackground

---

title: Memory limit exceeded in DEV mode

* DEV mode takes a lot of memory
* Stash Logging is the worst
* Disable Stash Logging in ezpublish.yml

<pre class="prettyprint" data-lang="yml">
stash:
    <b>logging: false</b>
    caches:
        default:
            handlers:
                - FileSystem
            inMemory: true
            registerDoctrineAdapter: false
</pre>

---

title: 414 Request-URI Too Long

When doing subrequests, particularly ESI or Hinclude ones, current SiteAccess is transmitted in a serialized form, with its matcher. With a large number of configured SiteAccesses using Map\Host or Map\URI matcher (around 40, which is not uncommon for a multi-national, multi-lingual site) the URL can exceed the size of 8192 Bytes which most servers accept. As a result, the ESI/Hinclude call fails.

* Fixed in Version 5.3.3 (2014.07)
* <https://jira.ez.no/browse/EZP-23168>
* <https://github.com/ezsystems/ezpublish-kernel/pull/949>

---

title: Multi-Site/Multi-Repository Setup
subtitle:
class: segue dark nobackground

---

title: Why a Multi-Site/Multi-Repository Setup?

* At CJW Network we have developed a multi-site/multi-repository setup for eZ Publish 4 several years ago
* This allows us to host many individual sites on a single eZ Publish installation

Advantages:

* Central site administration (site activation, cronjobs, ...)
* Easy deployment (update site extension with Subversion)
* Highly reduced maintenance costs (security patches, upgrades)
* Highly efficient use of hardware resources

Disadvantages:

* Some Kernel patches needed

---

title: Multi-Site/Multi-Repository Setup in eZ 5

First Approach (proven in production)

* Use different `ezpublish` directories to host the different sites

Second approach (under development)

* Use `CJW MultiSiteBundle`

---

title: TODO EKKE

---

title: Multi-Site-Setup (old) Directory structure

<pre class="">
ezpublish                &lt;-- not used
ezpublish_legacy
&#8990;extension
 &#8990;site_customer          &lt;-- each customer has its own extension and database
 &#8990;site_customertwo
&#8990;var
 &#8990;site_customer          &lt;-- each customer has its own var directory
 &#8990;site_customertwo
site_customer            &lt;-- each customer has its own Symfony app
site_customertwo
src
&#8990;CjwNetwork
 &#8990;SiteCustomerBundle     &lt;-- each customer has its own bundle
 &#8990;SiteCustomertwoBundle
</pre>

---

title: Multi-Site-Setup (old) Detail ezpublish_legacy

<pre class="">
ezpublish_legacy
&#8990;extension
 &#8990;site_customer          &lt;-- each customer has its own extension
  &#8990;classes
  &#8990;design
  &#8990;modules
  &#8990;settings
   &#8990;site.ini
    &#8990;[DatabaseSettings]  &lt;-- each customer has its own database
     &#8990;Database=database_site_customer
 &#8990;site_customertwo
  &#8990;[...]
  &#8990;settings
   &#8990;site.ini
    &#8990;[DatabaseSettings]
     &#8990;Database=database_site_customertwo
&#8990;var
 &#8990;site_customer          &lt;-- each customer has its own var directory
 &#8990;site_customertwo
</pre>

---

title: Multi-Site-Setup (old) Directory structure

<pre class="">
site_customer
&#8990;autoload.php
&#8990;bootstrap.php.cache
&#8990;cache
&#8990;check.php
&#8990;config    &lt;-- all yml files like ezpublish folder, (to improve)
 &#8990;config.yml
 &#8990;ezpublish.yml
&#8990; parameters.yml
&#8990;console
&#8990;logs
&#8990;phpunit.xml.dist
&#8990;Resources
&#8990;sessions
&#8990;SiteCjwbaseCache.php
&#8990;SiteCjwbaseKernel.php
&#8990;SymfonyRequirements.php
</pre>

---

title: END TODO EKKE

---

title: Introducing CJW MultiSiteBundle
build_lists: true

Although the first approach works fine, it has several drawbacks:

* Application code scattered at different places (site directory, bundle, legacy extension), hard to maintain in VCS, hard to deploy
* Redundancy in config files
* No global settings
* No central site activation/administration

* Goal: keep everything in one place!

---

title: CJW MultiSiteBundle Features
build_lists: true

* Boots kernel and environment based on domain name mappings
* Handles local, staging and live domain names
* Allows for global activation of bundles
* Allows for global settings
* Provides a common console for all sites
* Caches domain name mappings
* Moves cache and log files away from the ezpublish folder
* more to come ...

---

title: cjwpublish Directory

The `cjwpublish` application directory sits next to the `ezpublish` directory.

<pre class="">
cjwpublish
&#8990; config
    cjwpublish.yml                  &lt;-- defines active bundles
    config.yml                      &lt;-- allows for global settings
  CjwPublishKernel.php              &lt;-- inherits from CjwMultiSiteKernel.php
  CjwPublishCache.php               &lt;-- inherits from CjwMultiSiteCache.php
  console
</pre>

---

title: Symfony's app directory is back

Site Bundle Directory Layout

<pre class="">
src
&#8990; Cjw
  &#8990; SiteExampleBundle
    &#8990; app
      &#8990; config
          cjwpublish.yml            &lt;-- contains domain mappings
          config.yml
          ezpublish.yml
          ...
        CjwSiteExampleKernel.php    &lt;-- inherits from CjwPublishKernel.php
        CjwSiteExampleCache.php     &lt;-- inherits from CjwPublishCache.php
    &#8990; Controller
      ...
</pre>

---

title: Caveats

Adjustments needed in `config.yml` to reflect different relative location of kernel

<pre class="prettyprint" data-lang="yml">
assetic:
    ...
    read_from:      %kernel.root_dir%/../../../../web
    write_to:       %kernel.root_dir%/../../../../web
    ...
ez_publish_legacy:
    ...
    root_dir: %kernel.root_dir%/../../../../ezpublish_legacy

parameters:
    ezpublish.kernel.root_dir: %kernel.root_dir%/../../../../vendor/ezsystems/ezpublish-kernel
</pre>

**More problems of this kind expected!**

---

title: Project Status

* Currently in private Beta, not yet released
* Ideas and Feedback welcome
* Public Beta in October

* <mailto:info@cjw-network.com>
* <https://github.com/cjw-network/MultiSiteBundle>

---

title: Ressources

Slides as PDF

* see `src/Cjw/SummerCampBundle/Resources/doc`
* <https://github.com/cjw-network/SummerCampBundle/Resources/doc>

Slides (Source)

* <https://github.com/dfritschy/cjw-summercamp-slides>

CJW MultiSiteBundle

* <https://github.com/cjw-network/MultiSiteBundle>
* <mailto:info@cjw-network.com>
