# revdev #

`revdev` is a mechanism that facilitates the rapid setup of reverse proxies over SSH tunnels. The usual usecase is that you're happily hacking on your laptop behind a NAT, when you suddenly want your development setup to be reachable over the Internet (to show someone over a Skype convo, or to surf into it easily from a mobile device, or so the robot of some 3rd party site could reach it to scrape a shared page, etc).

Commonly you would have to push your code to an intermediary maching on the Internet (a staging/testing setup), but that's cumbersome. You're developing _now_, and just want Facebook to scrape this link _now_, and you have it working just right on _your_ box. I don't know what's your development cycle, I doubt it's as quick as spawning revdev.

With revdev, all you need to do is something like:

    ssh revdev@somehost.example.com foo

And automagically your client can surf to `http://foo.somehost.example.com` and see your site. And as soon as you break the ssh connection, _puff_, `foo.somehost.example.com` is no more. Cool, eh?

## Quickstart ##

Note that lines that start with `server#` should be run on the server as root, lines that start with `laptop$` should be run on your laptop as you. Also, note that this quickstart assumes your local development webserver is on port `8000`, if it isn't just change `8000` below to whatever port you use.

* Spin up an Ubuntu machine on your favorite provider and install git on it.
* Setup an `A` record (lets say, `somehost.example.com`) for this new machine.
* Setup a wildcard `CNAME` that points to the `A` record (`*.somehost.example.com`).
* `server# git clone https://github.com/yaniv-aknin/revdev.git /opt/revdev`
* `server# /opt/revdev/bootstrap.sh`
* `laptop$ wget http://revdev:secret@somehost.example.com/key -O ~/.ssh/revdev_rsa`
* `laptop$ chmod 600 ~/.ssh/revdev_rsa`
* `laptop$ ssh -i ~/.ssh/revdev_rsa -R localhost:0:localhost:8000 revdev@somehost.example.com somename`
* Anywhere on the Internet, surf to `http://somename.somehost.example.com`.
* Joy.

## How it works? ##

`nginx` is setup on the machine thus that it will load all the configuration files in `/opt/revdev/nginx/conf.d`. The generated ssh key will let you access a newly created `revdev` user, but in a limited fashion - the only thing you can do is run the `manager` script and setup reverse tunnels (from the server to your laptop). The management script, when run, will discover the port chosen for the reverse tunnel, and configure `nginx` to reverse proxy from the name you chose (say, `foo.somehost.example.com`) to the port. When the connection is broken, the script will clear the small configuration file.

## SSL ##

If you'd like your instance of revdev to support SSL, you need to supply it with a key and a certificate before bootstrapping. From the root directory of the cloned repository, do the following:

    $ mkdir ssl && cd ssl
    $ openssl req -new -nodes -keyout key.key -out certificate-request.csr
    # answer or hit return through lots of annoying questions; note that you need a
    # wildcard certificate, so make sure "Common Name" is something like *.somehost.example.com
    $ openssl x509 -req -days 365 -in certificate-request.csr -signkey key.key -out certificate.crt
    # ...
    $

And now run `bootstrap.sh`. The bootstrap process should find your certificate and key and configure `nginx` to also serve over SSL. This makes it less likely for you to realize only in staging that your webapp is hardcoded to load some resource from HTTP even when the rest of the site loads from HTTPS. Sweet.

(p.s.: it's up to you to configure your browser to trust this certificate, but that shan't be too hard; also, be absolutely sure you're creating a *wildcard* certificate, that's largely the point behind revdev...)

## OPTIONS ##

`bootstrap.sh` doesn't accept command line options, but you can control some of its behaviour using environment variables. For example, running `PROJECT_ROOT=/usr/local/revdev /usr/local/revdev/bootstrap.sh` will let you clone revdev to a directory other than `/opt/revdev`. The full list of environment variables is:

    PROJECT_ROOT            the location where you cloned the revdev repo
    REVDEV_KEY_USERNAME     the HTTP auth user used when serving the private ssh key
    REVDEV_KEY_PASSWORD     the HTTP auth password used when serving the private ssh key
    IDEMPOTENT              will let you run bootstrap.sh more than once; useful when hacking on revdev

## FAQ ##

*   **Q:** `bootstrap.sh` failed telling me I should run as root, run on Ubuntu, clone to a particular place and so on.

    **A:** Do as it told you.

*   **Q:** `bootstrap.sh` just failed (returned nonzero) with some other failure.

    **A:** Fork this repo, fix it, send me a pull request.

*   **Q:** Why is there no support for _name-of-distribution-which-isn't-Ubuntu_?

    **A:** Fork this repo, fix it, send me a pull request. Also, `bootstrap.sh` is rather easy to follow, I'm pretty sure you can hack it to match your system or do a manual walkthrough of what it does on your distribution. Unless it's Windows.

*   **Q:** The ssh command line is so long and icky... isn't there something that can be done about it?

    **A:** Sure. Add this to your `~/.ssh/config` file (change `somehost.example.com` to match your setup):

        Host somehost.example.com revdev
        Hostname somehost.example.com
        RemoteForward localhost:0 localhost:5000
        IdentityFile ~/.ssh/revdev_rsa
        User revdev

    Now you can simply run `ssh revdev foo` to create tunnel foo.

*   **Q:** I develop using `foreman`. Is there something totally cool you'd like to tell me?

    **A:** Yeah. Stick this in your `Procfile`:

        revdev: ssh -i ~/.ssh/revdev_rsa -R localhost:0:localhost:$PORT revdev@somehost.example.com $(hostname -s)

    There's a downside though: if the tunnel dies (which can be due to many things), foreman will tear down your whole development stack. You can write a script to wrap ssh thus that it will do retries for you, or fork foreman, add support for "optional" processes and send ddollar a pull request. If you do that, let me know too please. :)

*   **Q:** How secure is the server running revdev?

    **A:** The attack surface of an idle revdev server is just SSH. The private key is protected by a basic HTTP auth password (see *options* above for how to change the default password). Even if an attacker has the key, what can they do, given that they are forced to run a particular command and can only redirect ports to their own machine?

*   **Q:** How secure is my development machine when I expose it to the Internet?

    **A:** Quite possibly not secure. A future version of revdev may support HTTP authentication, albeit that kinda defeats the purpose of letting 3rd party scrapers scrape you. You can be quite secure if you open a revdev tunnel with a hard-to-guess-name (think `ssh revdev $(python -c 'import uuid ; print uuid.uuid4().hex')`).

*   **Q:** I don't want to go through the hassle of setting a server up. Why is there no revdev-as-a-service?

    **A:** I couldn't be bothered, and wasn't sure enough people would be interested. If you think you'd like to use a hosted revdev, drop me a line and tell me so, also mention how much you think you'd be willing to pay (if at all). If I see sufficient people that actually give a damn, I may actually put something up.

## Credits ##

`revdev` was conceived by Alon Hammerman and implemented by Yaniv Aknin (`@aknin`; [blog](http://tech.blog.aknin.name)). It's MIT licensed (see `LICENSE`), so you're free to do as you please, but if you use it, it would be nice of you to drop us a line.
