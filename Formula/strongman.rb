# typed: false
# frozen_string_literal: true

class Strongman < Formula
  include Language::Python::Virtualenv

  desc "Web UI for managing strongSwan via VICI on macOS"
  homepage "https://github.com/strongswan/strongMan"
  url "https://github.com/strongswan/strongMan.git",
      using: :git,
      branch: "master"
  version "0.0.0+master"
  license "MIT"

  depends_on "python@3.12"
  depends_on "strongswan"

  resource "django" do
    url "https://files.pythonhosted.org/packages/de/f1/230c6c20a77f8f1812c01dfd0166416e7c000a43e05f701b0b83301ebfc1/django-4.2.25.tar.gz"
    sha256 "2391ab3d78191caaae2c963c19fd70b99e9751008da22a0adcc667c5a4f8d311"
  end

  resource "gunicorn" do
    url "https://files.pythonhosted.org/packages/34/72/9614c465dc206155d93eff0ca20d42e1e35afc533971379482de953521a4/gunicorn-23.0.0.tar.gz"
    sha256 "f014447a0101dc57e294f6c18ca6b40227a4c90e9bdb586042628030cba004ec"
  end

  resource "asn1crypto" do
    url "https://files.pythonhosted.org/packages/de/cf/d547feed25b5244fcb9392e288ff9fdc3280b10260362fc45d37a798a6ee/asn1crypto-1.5.1.tar.gz"
    sha256 "13ae38502be632115abf8a24cbe5f4da52e3b5231990aff31123c805306ccb9c"
  end

  resource "pyaes" do
    url "https://files.pythonhosted.org/packages/44/66/2c17bae31c906613795711fc78045c285048168919ace2220daa372c7d72d/pyaes-1.6.1.tar.gz"
    sha256 "02c1b1405c38d3c370b085fb952dd8bea3fadcee6411ad99f312cc129c536d8f"
  end

  resource "django-tables2" do
    url "https://files.pythonhosted.org/packages/4b/89/e3a4dae972a4194f7ab83aa412fe56bf56c122eafe0fc7e6e34eb2749dc2/django-tables2-2.3.4.tar.gz"
    sha256 "50ccadbd13740a996d8a4d4f144ef80134745cd0b5ec278061537e341f5ef7a2"
  end

  resource "vici" do
    url "https://files.pythonhosted.org/packages/bd/bb/aca7726ef14d59d6a76f29dd61578a7877c73bd872d84d6f30dd58559a78/vici-5.8.4.tar.gz"
    sha256 "50156fa12219789c416e35729fa05f808a8e8c63e6baec79b2bb2991cffe53c0"
  end

  resource "dj-static" do
    url "https://files.pythonhosted.org/packages/2b/8f/77a4b8ec50c821193bf9682c7896f12fd0418eb3711a7d66796ede59c23b/dj-static-0.0.6.tar.gz"
    sha256 "032ec1c532617922e6e3e956d504a6fb1acce4fc1c7c94612d0fda21828ce8ef"
  end



  def install
    venv = virtualenv_create(libexec, "python3.12")
    venv.pip_install resources
    
    # Copy the strongMan source to make it importable
    site_packages = libexec/"lib/python3.12/site-packages"
    site_packages.install buildpath/"strongman"
    
    # Copy entire source tree to pkgshare for manage.py and static files
    pkgshare.install Dir["*"]

    # Runtime launcher script for gunicorn
    (libexec/"strongman-run").unlink if (libexec/"strongman-run").exist?
    (libexec/"strongman-run").write <<~EOS
      #!/bin/bash
      set -euo pipefail
      export VICI_HOST="${VICI_HOST:-127.0.0.1}"
      export VICI_PORT="${VICI_PORT:-4502}"
      UI_BIND="${UI_BIND:-0.0.0.0:1515}"
      WORKERS="${GUNICORN_WORKERS:-2}"

      # Set Python path to include the strongMan source
      export PYTHONPATH="#{pkgshare}:${PYTHONPATH:-}"
      
      # Some strongMan setups expect to run from the project dir (for static/templates)
      cd "#{pkgshare}"
      exec "#{libexec}/bin/gunicorn" \\
        "strongman.wsgi:application" \\
        --bind "${UI_BIND}" \\
        --workers "${WORKERS}"
    EOS
    chmod 0755, libexec/"strongman-run"

    # Convenience CLI to run in foreground (optional)
    (bin/"strongman").unlink if (bin/"strongman").exist?
    (bin/"strongman").write <<~EOS
      #!/bin/bash
      exec "#{libexec}/strongman-run" "$@"
    EOS
    chmod 0755, bin/"strongman"
  end

  service do
    run [opt_libexec/"strongman-run"]
    keep_alive true
    working_dir var
    log_path var/"log/strongman.log"
    error_log_path var/"log/strongman-error.log"
    environment_variables(
      "VICI_HOST" => "127.0.0.1",
      "VICI_PORT" => "4502",
      "UI_BIND" => "0.0.0.0:1515",
      "GUNICORN_WORKERS" => "2"
    )
  end

  def caveats
    <<~EOS
      1) Enable VICI in strongSwan (loopback-only):
         Intel: /usr/local/etc/strongswan.d/charon/vici.conf
         ARM:   /opt/homebrew/etc/strongswan.d/charon/vici.conf

         vici {
           socket = unix:///usr/local/var/run/charon.vici
           tcp = yes
           tcp_listen = 127.0.0.1
           tcp_port = 4502
         }

         Then:  sudo ipsec restart

      2) Start strongMan:
         brew services start strongman          # user agent (after login)
         sudo brew services start strongman     # system daemon (boot before login)

      3) First-time admin:
         cd #{opt_pkgshare}
         #{opt_libexec}/bin/python manage.py createsuperuser

      UI:  http://<host>:1515/
      Logs: #{var}/log/strongman.log , #{var}/log/strongman-error.log
    EOS
  end

  test do
    # Just confirm our wrapper is present and executable
    assert_predicate bin/"strongman", :executable?
  end
end