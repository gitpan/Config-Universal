#
#  Universal::Config
#
#  Maintained by  Hartmut Vogler (hartmut.vogler@t-systems.com,it@guru.de)
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
#
package Config::Universal;
use 5.005;
use strict;


=head1 NAME

Config::Universal - Universal object oriented config file reader

=begin __INTERNALS

=head1 PORTABILITY

At this time, it is only tested on Linux, but perhaps it is
writen in nativ perl, it should be no problem to use it on
other platforms.

=back

=end __INTERNALS

=head1 SYNOPSIS

  use Config::Universal;

  my $conf=new Config::Universal();
  
=head1 DESCRIPTION

This module is designed to read object structured config files.

=head1 METHODS

=over 4

=cut

use vars qw($VERSION); 

$VERSION = '0.2';


sub new
{
   my $type=shift;
   my $self={};

   return(bless($self,$type));
}

=item C<ReadConfigFile>($filename)

This method reads the config file. If this fails, the method
returns a non zero value.

=cut

sub ReadConfigFile
{
   my $self=shift;

   foreach my $filename (@_){
      my $result=$self->_ReadConfigFile($filename);
      return($result) if ($result);
   }
   return(0);
}

sub _ReadConfigFile
{
   my $self=shift;
   my $configfilename=shift;

   if (open(F,"<$configfilename")){
      my $line=0;
      my $buffer="";
      my $currentname=undef;
      my $mode=undef;
      my @param=();
      my $errormsg=undef;
      my %config=();
      my %globalconfig=();
      my %cfgbuf=();
      my @curcfgbuf=\%cfgbuf;
      my $objlevel=0;
      while(my $l=<F>){
         next if ($l=~m/^\s*#.*$/ && $buffer eq "");
         $l=~s/\s*$//;
         $line++;
         $buffer.=$l;
         if ($l=~m/\\$/){
            $buffer=~s/\\$//;
            next;
         }
         $buffer=~s/\\"/\0/g;
         while($buffer ne ""){
            my $vari;
            if ($buffer=~m/^\s*{/){
               $buffer=~s/^\s*{//;
               my $objectname=undef;
               if ($mode eq ""){
                  $objectname=FindFreeObjectName(\%cfgbuf,"*",""); 
               }
               elsif($mode eq "Name"){
                  if ($param[0] eq "'%GLOBAL%'" || $param[0]=~m/[\s:\.\@]/){
                     printf STDERR ("ERROR: invalid class '$param[0]' ".
                                    "in $configfilename at $line\n");
                     exit(1);
                  }
                  $objectname=FindFreeObjectName(\%cfgbuf,$param[0],$param[0]); 
                  $mode="";
               }
               elsif($mode eq "NameQuoteStartDataQuoteEnd"){
                  if ($param[0] eq "'%GLOBAL%'" || $param[0]=~m/[\s:\.\@]/){
                     printf STDERR ("ERROR: invalid class '$param[0]' ".
                                    "in $configfilename at $line\n");
                     exit(1);
                  }
                  if ($param[1]=~m/[\s\.\@:]/){
                     printf STDERR ("ERROR: invalid object name '$param[1]' ".
                                    "in $configfilename at $line\n");
                     exit(1);
                  }
                  $objectname=$param[0].":".$param[1]; 
                  $mode="";
               }
               else{
                  $errormsg="unexpected object open '$mode'";
               }
               if (!defined($errormsg) && $objectname ne ""){
                  my ($shortname)=$objectname=~m/:([^:]+$)/;
                  $curcfgbuf[0]->{$objectname}={name=>$shortname};
                  unshift(@curcfgbuf,$curcfgbuf[0]->{$objectname});
                  $objlevel++;
                  @param=();
               }
            }
            elsif (!defined($errormsg) &&
                   $buffer=~m/^\s*}/){
               $buffer=~s/^\s*}//;
               $errormsg="unterminated command sequenz" if ($mode ne "");
               $objlevel--;
               if ($objlevel<0){
                  $errormsg="unexpected object close";
               }
               shift(@curcfgbuf);
            }
            elsif (!defined($errormsg) &&
                   $buffer=~m/^\s*"/ && ($mode=~m/Data$/)){
               $buffer=~s/^\s*"//;
               $errormsg="unexpected quote" if ($mode=~m/QuoteEnd/);
               if ($buffer=~/^\s*\,/){
                  $buffer=~s/^\s*\,//;
                  $mode.="ArraySep";
               }
               else{ 
                  $mode.="QuoteEnd";
               }
            }
            elsif (!defined($errormsg) &&
                   (($vari)=$buffer=~m/^([^"]*)/) && ($mode=~m/QuoteStart$/)){
               $buffer=~s/^([^"]*)//;
               $vari=~s/\0/"/g;
               push(@param,$vari);
               $mode.="Data";
            }
            elsif (!defined($errormsg) &&
                   (($vari)=$buffer=~m/^\s*([a-zA-Z0-9_]+)/)){
               $buffer=~s/^\s*([a-zA-Z0-9_]+)//;
               push(@param,$vari);
               $mode.="Name";
            }
            elsif (!defined($errormsg) &&
                   $buffer=~m/^\s*=/){
               $buffer=~s/^\s*=//;
               $mode.="Setvar";
            }
            elsif (!defined($errormsg) &&
                   ($buffer=~m/^\s*"/) && 
                   (($mode=~m/Setvar$/) || ($mode=~m/ArraySep$/) ||
                    ($mode=~m/Name$/))){
               $errormsg="unexpected \""      if (!($mode=~m/Setvar$/) &&
                                                  !($mode=~m/ArraySep$/)
                                                   && $mode ne "Name");
               $buffer=~s/^\s*"//;
               $mode.="QuoteStart";
            }
            elsif (!defined($errormsg) &&
                   (my ($incfile)=$buffer=~m/^\@INCLUDE\s+\"(.+)\"/)){
               $buffer=~s/^\@INCLUDE\s+\".+\"//;
               if ($mode eq "" && $objlevel==0){
                  my $result=$self->_ReadConfigFile($incfile);
                  return($result) if ($result); 
               }
               else{
                  $errormsg="\@INCLUDE not allowed in control structur";
               }
            }
            else{
               $errormsg="syntax error";
            }
            if (defined($errormsg)){
               printf STDERR ("LINE:  '$l'\n");
               printf STDERR ("ERROR: $errormsg in line $line\n");
               exit(1);
            }
            #printf("level=$objlevel mode='$mode' buffer='$buffer'\n");
            if ($mode eq "NameSetvarQuoteStartDataQuoteEnd" ||
                $mode=~m/^NameSetvarQuoteStartDataArraySep.*QuoteEnd$/){
               #printf("fifi found mode='$mode'  '%s'\n",join(",",@param));
               my $variname=shift(@param);
               my $cfgwork=$curcfgbuf[0];
               $cfgwork=\%globalconfig if ($objlevel==0);
               if ($#param==0 && $variname ne "alias"){
                  $cfgwork->{$variname}=$param[0];
               }
               else{
                  $cfgwork->{$variname}=[@param];
               }
               $mode="";
               @param=();
            }
         }
      } 
      #print Dumper(\%cfgbuf);
      MergeObjects(\%cfgbuf,\%globalconfig,$self);
      if ($objlevel!=0){
         printf STDERR ("ERROR: unexpected eof in '$configfilename' ".
                        "at $line\n");
         exit(1);
      }
      close(F);
      #print Dumper(\%{$self});
      return(0);
   }
   return(int($!));
}

sub MergeObjects
{
   my $src=shift;
   my $globalconfig=shift;
   my $dst=shift;

   while(my $obj=FetchObject($src,{},undef,undef)){
      foreach my $key (keys(%{$obj})){
         my ($class,$name)=split(/:/,$key);
         if ($class ne "*"){
            $dst->{$class}->{$name}=$obj->{$key};
         }
      }
   }
   foreach my $key (keys(%{$globalconfig})){
      $dst->{'%GLOBAL%'}->{$key}=$globalconfig->{$key};
   }
}

sub FetchObject
{
   my $src=shift;
   my $buf=shift;
   my $parent=shift;
   my $name=shift;
   my $hname=undef;
   my %mybuf=%{$buf};

   foreach my $key (keys(%{$src})){
      if (ref($src->{$key}) eq "HASH"){
         $hname=$key;
      }
      else{
         $mybuf{$key}=$src->{$key};
      }
   } 
   if ($hname){
      my $tempobj=FetchObject($src->{$hname},\%mybuf,$src,$hname);
      return($tempobj);
   }
   delete($parent->{$name}) if (defined($parent));
   return(undef) if (!defined($name));
   return({$name=>\%mybuf});
}



sub FindFreeObjectName
{
   my $config=shift;
   my $class=shift;
   my $basename=shift;
   my $c=0;
   my $name;

   while(1){
      $name=sprintf("%s:%s%04d",$class,$basename,$c);
      last if (!IsKeyInUse($config,$name));
      $c++;
   }
   return($name);
}

sub IsKeyInUse
{
   my $cfgpoint=shift;
   my $k=shift;
   foreach my $chkkey (keys(%{$cfgpoint})){
      return(1) if ($chkkey eq $k);
      if (ref($cfgpoint->{$chkkey}) eq "HASH"){
         return(1) if (IsKeyInUse($cfgpoint->{$chkkey},$k));
      }
   }
   return(0);
}

=item C<GetVar>()

=item C<GetVar>($varname)

With no $varname, the list of global variables in the configfile
is returned. If the $varname is specified, the value of the given
name is returned.

=cut

sub GetVar
{
   my $self=shift;
   my $varname=shift;   # if not spezified, the list of global vars ar returned
   if (!defined($varname)){
      return(keys(%{$self->{'%GLOBAL%'}}));
   }
   if (defined($self->{'%GLOBAL%'}->{$varname})){
      return($self->{'%GLOBAL%'}->{$varname});
   }
   return("undef");
}  

=item C<GetObject>()

=item C<GetObject>($objecttype)

=item C<GetObject>($objecttype,$objectname)

With no paramaters, the method returns the list of available
object types in current config.

If the $objecttype is specified, the list of objectnames in the
given $objecttype is returned.

If $objecttype and $objectname is specified, the value ob the
described variable is returned.

=cut

sub GetObject
{
   my $self=shift;
   my $class=shift; 
   my $objname=shift;   # if not spezified, the list of objects are returned

   if (!defined($class)){
      return(grep(!/^\%GLOBAL\%$/,keys(%{$self})));
   }
   if (!defined($objname)){
      if (defined($self->{$class})){
         return(keys(%{$self->{$class}}));
      }
      else{
         return(undef);
      }
   }
   else{
      if (defined($self->{$class}) &&
          defined($self->{$class}->{$objname})){
         return($self->{$class}->{$objname});
      }
      else{
         if (defined($self->{$class})){
            # find alias
            foreach my $objname (keys(%{$self->{$class}})){
               if (grep(/^$objname$/,@{$self->{$class}->{$objname}->{alias}})){
                  return($self->{$class}->{$objname});
               }
            }
            return(undef);
         }
         else{
            return(undef);
         }
      }
   }
}


=head1 AUTHORS

Config::Universal by Hartmut Vogler.

=head1 COPYRIGHT

The Config::Universal is Copyright (c) 2005 Hartmut Vogler. Germany.
All rights reserved.

=cut


1;
