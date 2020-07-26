#!/usr/bin/env perl
eval 'exec /usr/bin/env perl -wS $0 ${1+"$@"}'
  if our $running_under_some_shell;

package PAM_Group;
use strict;
use warnings;
use utf8;
use MOP4Import::Base::CLI_JSON -as_base
  , [fields =>
     [username  => doc => "Override PAM_USER (for test)"],
     ['dry-run' => doc => "Don't actually run any updates"],
   ];

use IPC::Run;
use User::pwent;
use User::grent;
use Unix::Groups::FFI;

sub grouplist : Doc(PAM_USER/--username の参加グループ一覧を取得) {
  (my MY $self) = @_;

  defined ($self->{username} //= $ENV{PAM_USER})
    or Carp::croak "PAM_USER is required";

  my $user = getpwnam($self->{username})
    or Carp::croak "No such user: $self->{username}";

  map {
    if (my $gr = getgrgid($_)) {
      $gr
    } else {
      $_
    }
  } Unix::Groups::FFI::getgrouplist($self->{username}, $user->gid);
}

sub list_group_updates : Doc(更新を要するグループの一覧を作成) {
  (my MY $self, my $configFn) = @_;

  my (%current, @unknown);
  foreach my $group ($self->grouplist) {
    if (not ref $group) {
      push @unknown, [$group]; # special marker for user-group
    }
    else {
      $current{$group->name} = $group;
    }
  }

  if (@unknown >= 2) {
    Carp::croak "Too many unknown(unnamed) gids! @unknown";
  }

  push @unknown, grep {not $current{$_}} $self->cli_read_file__txt($configFn);

  @unknown;
}

sub execute :Doc(コマンドを表示し、実行する(--dry-runなら何もしない)) {
  (my MY $self, my ($cmd, @args)) = @_;

  $self->cli_output([[$cmd, @args]]);

  return if $self->{'dry-run'};

  system($cmd, @args) == 0
    or Carp::croak "ERROR: $cmd @args failed: $?";
}

sub cmd_do_update : Doc(PAM_USER を configFn に書かれたグループに加える(未参加時のみ更新)) {
  (my MY $self, my $configFn) = @_;

  my @unknown = $self->list_group_updates($configFn);

  foreach my $update (@unknown) {
    if (ref $update) {
      $self->execute("/usr/sbin/groupadd" => -g => $update->[0], $self->{username})
    }
    else {
      $self->execute("/usr/sbin/usermod" => -aG => $update, $self->{username})
    }
  }
}

MY->cli_run(\@ARGV) unless caller;

1;
