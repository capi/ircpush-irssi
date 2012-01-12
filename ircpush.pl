#!/usr/bin/perl -w

#####
# ircpush.pl: push private messages and hilights to an ircpush server
# Copyright (C) 2012 Martin Carpella <martin.carpella@gmx.net>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# http://www.gnu.org/licenses/gpl-2.0.txt
# --------------------------------------------------------------------------
#
# Tool that pushes messages containing your nick name and private messages
# to a configured ircpushd server, which will then forward it to your
# Android handset.
#
# Please visit the project's homepage at http://ircpush.dont-panic.cc/ for
# further information.
#
# settings:
# ---------
# /set ircpushd_server (string)
#   set the hostname of the server to push to
#   IMPORTANT: you always need to configure this setting when installing!
#
# /set ircpushd_port (integer, 1-65535)
#   the port to connect to (26144 as default)
#
# /set ircpush_auth_token (string)
#   the authentication at the ircpush server. this needs to match your
#   auth-token there and the one used on the mobile phone.
#   please note, that this is the _only_ security option that prevents
#   others from receiving your messages. it needs to be as strong as
#   possible. therefore we suggest tokens >= 24 chars MINIMUM.
#   this needs to be kept secret from others, treat it like a password
#   (which it actually is!). beware, that it will be saved in your
#   $HOME/.irssi/config file, so beware when sharing this file with
#   others!
#
# /set ircpushd_away_only (boolean)
#   if set (default "on"), will only push messages when the user is set
#   to AWAY in IRC. this is very useful for combination with the
#   "screen_away" script.
#
# /set ircpush_debug (boolean)
#   if set (default "off") will print diagnostic information when
#   trying to send information to the ircpush server. it will
#   display information about missing information and the
#   actual string it is trying to push.
#   beware that this debug string will contain your auth-token!
#
#
# network connections & security:
# -------------------------------
# 
# this script always uses a SSL connection and therefore needs
# IO::Socket::SSL perl module, which should be available on any Debian
# Linux (including Ubuntu) in the repository. otherwise, you can always
# get it from CPAN.
# please beware that the current version does not perform any checks
# on the remote SSL certificate, so man-in-the-middle attacks are
# possible.
# 
# please also note that even with debug enabled, no information if
# the remote server had been reachable will be printed. there is no
# guaranee if a message is delivered.
#
#
# version history:
# ----------------
#
# 0.1, 2012-01-12
#   initial working version, SSL only, no cert-checks
#

use strict;
use warnings;

use IO::Socket::SSL;
use Irssi;
use Irssi::Irc;
use vars qw($VERSION %IRSSI %config);

$VERSION = "0.2";

%IRSSI = (
  authors => "Martin Carpella",
  contact => "martin.carpella\@gmx.net",
  name => "ircpush",
  description => "Sends hilighted and priv messages to ircpushd.",
  license => "GPLv2",
  url => "http://ircpush.dont-panic.cc/",
);

my %config;

sub debug {
  our %config;
  if ($config{debug}) {
    my $text = shift;
    my $caller = caller;
    if ($1) {
      Irssi::print('From ' . $caller . ":\n" . $text);
    } else {
      Irssi::print($text);
    }
  }
}

sub read_config {
  our %config;
  $config{'server'} = Irssi::settings_get_str("ircpush_server");
  $config{'port'} = Irssi::settings_get_int("ircpush_port");
  $config{'authtoken'} = Irssi::settings_get_str("ircpush_auth_token");
  $config{'awayonly'} = Irssi::settings_get_bool("ircpush_away_only");
  $config{'debug'} = Irssi::settings_get_str("ircpush_debug");
  #debug("-------", 0);
  #debug("read_config:", 0);
  #foreach my $key (keys %config) {
  #  debug("$key: $config{$key}", 0);
  #}
  #debug("-------", 0);
}

sub escape {
  my $str = $_[0];
  $str =~ s/\\/\\\\/g;
  $str =~ s/\"/\\\"/g;
  $str =~ s/\s/ /g;
  return $str;
}

sub send_notify {
  my ($room, $sender, $message) = @_;
  our %config;
  my $authtoken = $config{'authtoken'};
  my $server = $config{'server'};
  my $port = $config{'port'};
  if ($authtoken eq "") {
    debug("Missing auth-token for push!", 0);
    return;
  }
  if ($server eq "") {
    debug("Missing push server!", 0);
    return
  }
  debug("Sending notify to $server:$port...", 0);

  return if $authtoken eq "";
  my $sock = IO::Socket::SSL->new("$server:$port");
  $authtoken = escape($authtoken);
  $message = escape($message);
  $sender = escape($sender);
  $room = escape ($room);
  my $cmd = "{\"auth-token\":\"$authtoken\",\"message\":\"$message\",\"sender\":\"$sender\",\"badge\": 1,\"room\":\"$room\"}";
  debug($cmd, 0);
  print $sock $cmd;
  $sock->close(SSL_ctx_free=>1);
}

sub msg_pub {
   my ($server, $data, $nick, $mask, $target) = @_;
   our %config;
   if (($server->{usermode_away} || !$config{'awayonly'}) && $data =~ /$server->{nick}/i) {
     send_notify($target, $nick, $data);
   }
}

sub msg_priv {
   my ($server, $data, $nick, $address) = @_;
   our %config;
   if ($server->{usermode_away} || !$config{'awayonly'}) {
     send_notify("", $nick, $data);
   }
}

Irssi::settings_add_str("ircpush", "ircpush_server" => "localhost");
Irssi::settings_add_int("ircpush", "ircpush_port" => 26144);
Irssi::settings_add_str("ircpush", "ircpush_auth_token" => "");
Irssi::settings_add_bool("ircpush", "ircpush_away_only" => 1);
Irssi::settings_add_bool("ircpush", "ircpush_debug" => 0);

read_config();

Irssi::signal_add_last('setup changed', "read_config");
Irssi::signal_add_last('message public', 'msg_pub');
Irssi::signal_add_last('message private', 'msg_priv');

