# revdev #

`revdev` is a mechanism that facilitates the rapid setup of reverse proxies over SSH tunnels. The usual usecase is that you're happily hacking on your laptop behind a NAT, when you suddenly want your development setup to be reachable over the Internet (to show someone over a Skype convo, or to surf into it easily from a mobile device, or so the robot of some 3rd party site could reach it to scrape a shared page, etc).

Commonly you would have to push your code to an intermediary maching on the Internet (a staging/testing setup), but that's cumbersome. You're developing _now_, and just want Facebook to scrape this link _now_, and you have it working just right on _your_ box, and screw the friggin' deployment cycle which forces you to take a coffee break (if you're working in a tidy and disciplined team) or mutter and curse as you `ssh` into a bunch of servers and tinker with things (if you're like the rest of us bums).

With `revdev`, all you need to do is something like:

    ssh revdev@somehost.example.com foo

And automagically your boss can surf to `http://foo.somehost.example.com` and see your site. And as soon as you break the ssh connection, _puff_, `foo.somehost.example.com` is no more. Cool, eh?

## Quickstart ##

Note that lines that start with `server#` should be run on the server as root, lines that start with `laptop$` should be run on your laptop as you. Also, note that this quickstart assumes your local development webserver is on port `8000`, if it isn't just change `8000` below to whatever port you use.

* Spin up an Ubuntu machine on your favorite provider and install git on it.
* Setup an `A` record (lets say, `somehost.example.com`) for this new machine.
* Setup a wildcard `CNAME` that points to the `A` record (`*.somehost.example.com`).
* `server# git clone https://github.com/yaniv-aknin/revdev.git /opt/revdev`
* `server# /opt/revdev/bootstrap.sh`
* `laptop$ wget http://somehost.example.com/key -O ~/.ssh/revdev_rsa`
* `laptop$ chmod 600 ~/.ssh/revdev_rsa`
* `laptop$ ssh -i ~/.ssh/revdev_rsa -R localhost:0:localhost:8000 revdev@somehost.example.com somename`
* Anywhere on the Internet, surf to `http://somename.somehost.example.com`.
* Joy.

## How it works? ##

`nginx` is setup on the machine thus that it will load all the configuration files in `/opt/revdev/nginx/conf.d`. The generated ssh key will let you access a newly created `revdev` user, but in a limited fashion - the only thing you can do is run the `manager` script and setup reverse tunnels (from the server to your laptop). The management script, when run, will discover the port chosen for the reverse tunnel, and configure nginx to reverse proxy from the name you chose (say, `foo.somehost.example.com`) to the port. When the connection is broken, the script will clear the small configuration file.

## FAQ ##

*   **Q:** `bootstrap.sh` failed telling me I should run as root, run on Ubuntu, clone to a particular place and so on.

    **A:** Do as it told you.

*   **Q:** `bootstrap.sh` just failed (returned nonzero) with some other failure.

    **A:** Fork this repo, fix it, send me a pull request.

*   **Q:** Why is there no support for _name-of-distribution-which-isn't-Ubuntu_)?

    **A:** Fork this repo, fix it, send me a pull request. Also, `bootstrap.sh` is rather easy to follow, I'm pretty sure you can hack it to match your system or do a manual walkthrough of what it does on your distribution. Unless it's Windows.

*   **Q:** What about SSL, to satisfy them paranoid Facebook scrapers?

    **A:** Ah, great question. It's in the works (that was the idea behind `revdev` in the first place).

*   **Q:** The ssh command line is so long and icky... isn't there something that can be done about it?

    **A:** Sure. Add this to your `~/.ssh/config` file (change `somehost.example.com` to match your setup):

        Host somehost.example.com revdev
        Hostname somehost.example.com
        RemoteForward localhost:0 localhost:5000
        IdentityFile ~/.ssh/revdev_rsa
        User revdev

    Now you can simply run `ssh revdev foo` to create tunnel foo.

*   **Q:** Isn't it insecure, publishing the private key and letting anyone ssh into the revdev server?

    **A:** Depends. I admit the best practice would be to run `server# rm /opt/revdev/www/key` after you got the key. But I really don't see what would anyone do with it, given that they are forced to run a particular command and can only redirect ports to their own machine.

*   **Q:** Isn't it insecure, exposing the development webserver I run on my laptop to the Internet?

    **A:** Probably. A future version of revdev may support HTTP authentication, albeit that kinda defeats the purpose of letting 3rd party scrapers scrape you. Another option is for you to open a revdev tunnel with a hard-to-guess-name (think `ssh revdev $(python -c 'import uuid ; print uuid.uuid4().hex')`).

## Credits ##

`revdev` was conceived by Alon Hammerman and implemented by Yaniv Aknin (`@aknin`; [blog](http://tech.blog.aknin.name)). It's MIT licensed (see `LICENSE`), so you're free to do as you please, but it would be nice if you drop us a line, letting us know you're using it.