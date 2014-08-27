title: Presenters
class: big
build_lists: true

<!---

  eZ Summercamp 2014 Talk

  Learnings from Real eZ Publish 5 Projects

  (c) 2014 Ekkehard Dörre, Donat Fritschy

-->

* <strong>Ekke</strong> is a consultant with deep knowledge in eZ Publish 4 and 5, eZ Find / Apache Solr and with a faible for coming cutting edge web technologies. He is one of the organizers of the PHP Unconference since seven years.
* <strong>Donat</strong> is owner of Webmanufaktur, a full service web agency in Switzerland. He works as projects manager, software architect and developer and likes thinking outside of the box. In the last year he has been involved in major eZ 5 projects.
* Members of CJW Network

---

title: Learnings from Real eZ Publish 5 Projects
class: big
build_lists: true

- Last year we have presented our Cookbok
- In the meantime we have realized a couple of larger and smaller eZ 5 projects
- We want to share these experiences

---

title: Agenda
class: big
build_lists: true

Things we'll cover:

- Best Practice
- Debugging
- Pitfalls

- MultiSite Setup

---

title: Best Practice
subtitle:
class: segue dark nobackground

---

title: TODO einzelne Slides

- Project Layout
- Config Files
- Controller per Full View
- Base Bundle

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

title: Introducing CJW MultiSiteBundle
build_lists: true

Although the first approach works fine, it has several drawbacks:

* Application code scattered at different places (site directory, bundle, legacy extension), hard to maintain in VCS, hard to deploy
* Redundancy in config files
* No global settings
* No central site activation/administration

Goal: keep everything in one place!

---

title: CJW MultiSiteBundle Features

* Boots kernel and environment based on domain name mappings
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
  &#8990; SiteExample
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

