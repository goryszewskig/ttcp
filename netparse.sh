#!/bin/bash 


usage()
{
cat << EOF
usage: $0 options  [output files]
 
parse netperf.sh output files, output parsed results

OPTIONS:
   -h              Show this message
   -v              verbose, include histograms in output
EOF
}

# bit of a hack
# shell script takes command line args
# these args are then passed into perl at command line args
# the perl looks at each commandline arge and sets a 
# variable with that name = 1
#
AGRUMENTS=""
VERBOSE=0
while getopts .dC:J:chpR:vr. OPTION
do
     case $OPTION in
         h)
             usage
             exit 1
             ;;
         v)
             ARGUMENTS="$ARGUMENTS verbose"
             VERBOSE=1
             ;;
         ?)
             usage
             exit
             ;;
     esac
done
shift $((OPTIND-1))

for i in $*; do
  echo "filename=$i"
  cat $i 
  echo "FILE_END"
done | \
perl -e '

  $SEP=$ENV{'SEP'}||",";

  use POSIX;

  $first=1;

  $ouputrows=0;
  $DEBUG=0;
  $CLAT=0;

     if  ( 1 == $DEBUG ) { $debug=1; }

     foreach $argnum (0 .. $#ARGV) {
        ${$ARGV[$argnum]}=1;
       #print "$ARGV[$argnum]=${$ARGV[$argnum]}\n";
     }
     print "continuting ... \n" if defined ($debug);

     $| = 1;
     printf("before input\n") if defined ($debug);
     while (my $line = <STDIN>) {
        printf("after input\n") if defined ($debug);
        chomp($line);
        printf("line: %s\n", $line) if defined ($debug);
        if ( $line =~ m/Total transferred bytes:/ )  { ($name,$bytes)   = split(":", $line); }
        if ( $line =~ m/     Total run nano time:/ ) { ($name,$nano)    = split(":", $line); 
                                                       if ( $maxnano < $nano || $maxnano == 0 ) { $maxnano=$nano }
                                                     }
        if ( $line =~ m/RETRANS/ ) { ($name,$retrans_beg,$retrans_end)      = split(":", $line); }
        if ( $line =~ m/            Message size:/ ) { ($name,$message_size)      = split(":", $line); }
        if ( $line =~ m/        Send buffer size:/ ) { ($name,$local_send_size)   = split(":", $line); }
        if ( $line =~ m/     Receive buffer size:/ ) { ($name,$local_recv_size)   = split(":", $line); }
        if ( $line =~ m/   Peer send buffer size:/ ) { ($name,$remote_send_size)  = split(":", $line); }
        if ( $line =~ m/Peer receive buffer size:/ ) { ($name,$remote_recv_size)  = split(":", $line); }
       #if ( $line =~ m/     Using direct buffer:/ ) { ($name,$local_send_size)   = split(":", $line); }
       #if ( $line =~ m/         Using async NIO:/ ) { ($name,$local_send_size)   = split(":", $line); }
       #if ( $line =~ m/             SSL enabled:/ ) { ($name,$local_send_size)   = split(":", $line); }
        if ( $line =~ m/        Latency .us.msg.:/ ) { ($name,$value)    = split(":", $line); $avgmsg += $value;}
        if ( $line =~ m/                 maximum:/ ) { ($name,$maxl)    = split(":", $line); 
                                                       if ( $maxl < $max || $max == 0 ) { $max=$maxl }
                                                     }
        if ( $line =~ m/                 minimum:/ ) { ($name,$minl)    = split(":", $line); 
                                                       if ( $minl < $min || $min == 0 ) { $min=$minl }
                                                     }
        if ( $line =~ m/                    mean:/ ) { ($name,$meanl)   = split(":", $line); }
        if ( $line =~ m/      standard deviation:/ ) { ($name,$std)     = split(":", $line); }
        if ( $line =~ m/           50 percentile:/ ) { ($name,$p50)     = split(":", $line); }
        if ( $line =~ m/           95 percentile:/ ) { ($name,$p95)     = split(":", $line); }
        if ( $line =~ m/            <         10:/ ) { ($name,$value)   = split(":", $line); $us10+=$us10+$value; }
        if ( $line =~ m/            <         50:/ ) { ($name,$value)   = split(":", $line); $us50+=$us50+$value; }
        if ( $line =~ m/            <        100:/ ) { ($name,$value)   = split(":", $line); $us100+=$us100+$value; }
        if ( $line =~ m/            <        500:/ ) { ($name,$value)   = split(":", $line); $us500+=$us500+$value; }
        if ( $line =~ m/            <       1000:/ ) { ($name,$value)   = split(":", $line); $us1000+=$us1000+$value; }
        if ( $line =~ m/            <       5000:/ ) { ($name,$value)   = split(":", $line); $us5000+=$us5000+$value; }
        if ( $line =~ m/            <      10000:/ ) { ($name,$value)   = split(":", $line); $us10000+=$us10000+$value; }
        if ( $line =~ m/            <      50000:/ ) { ($name,$value)   = split(":", $line); $us50000+=$us50000+$value; }
        if ( $line =~ m/            <     100000:/ ) { ($name,$value)   = split(":", $line); $us100000+=$us100000+$value; }
        if ( $line =~ m/            <     500000:/ ) { ($name,$value)   = split(":", $line); $us500000+=$us500000+$value; }
        if ( $line =~ m/            <    1000000:/ ) { ($name,$value)   = split(":", $line); $us1000000+=$us1000000+$value; }
        if ( $line =~ m/         Average latency:/ ) { ($name,$avgl)  = split(":", $line); }

        if ( $line =~ m/worker/ || $line =~ /summary/ ) { 
                #printf("%s: %d\n","bytes",$bytes) if defined ($debug);
                if ( $worker > 0 || $line =~ /summary/ ) {
                  $throughput[$worker]=($bytes/(1024*1024))/($nano/(1000*1000*1000)); 
                  $total_bytes+=$bytes;
                  $total_nano+=$nano;
                  if ( 1 == 0 ) {
                    printf("throughput[%d]=%7.2f=%7.2f=%d/%d total_MB  %d, total_ms=%d total_throughput= %7.2f\n", 
                                 $worker,
                                 ($bytes/(1024*1024))/($nano/(1000*1000*1000)), 
                                 $throughput[$worker],
                                 $bytes/(1024*1024),
                                 $nano/(1000*1000*1000), 
                                 $total_bytes/(1024*1024),
                                 $total_nano/(1000*1000*1000),
                                 ($total_bytes/(1024*1024))/($total_nano/(1000*1000*1000)) );
                  }
                }
                if (   $line !~ /summary/ ) { $worker++;  }
                #printf("workers=%d\n",$worker);
        }


 # ====================================================================
 #
 #   PRINTING OUT
 #

    if ( $line =~ m/FILE_END/ ) {

      # calculate THROUGPUT as sum of each thread throughput

        for ( $i=1; $i<=$worker; $i++ ) {
           $total_throughput += $throughput[$i];
           #printf("total_throughput: %7.2f throughput[%d]:%7.2f\n", $total_throughput,$i,$throughput[$i]);
        }

      #  calculate THROUGHPUT as (total bytes / maximum elapsed time)

      if ( $total_nano > 0 ) {
         $sMBsec=($total_bytes/(1024*1024))/($maxnano/(1000*1000*1000));
      } else {
         $sMBsec= -1;
      }


     # DEBUG
        printf("%s: %d\n","bytes",$bytes) if defined ($debug);
        printf("%s: %d\n","nano",$nano) if defined ($debug);
        printf("%s: %d\n","message_size",$message_size) if defined ($debug);
        printf("%s: %d\n","local_send_size",$local_send_size) if defined ($debug);
        printf("%s: %d\n","local_recv_size",$local_recv_size) if defined ($debug);
        printf("%s: %d\n","remote_send_size",$remote_send_size) if defined ($debug);
        printf("%s: %d\n","remote_remote_recv_size",$remote_recv_size) if defined ($debug);
        printf("%s: %d\n","avgl",$avgl) if defined ($debug);
        printf("%s: %d\n","minl",$minl) if defined ($debug);
        printf("%s: %d\n","maxl",$maxl) if defined ($debug);
        printf("%s: %d\n","meanl",$meanl) if defined ($debug);
        printf("%s: %d\n","std",$std) if defined ($debug);
        printf("%s: %d\n","p50",$p50) if defined ($debug);
        printf("%s: %d\n","p95",$p95) if defined ($debug);
        printf("%s: %d\n","us10",$us10) if defined ($debug);
        printf("%s: %d\n","us50",$us50) if defined ($debug);
        printf("%s: %d\n","us100",$us100) if defined ($debug);
        printf("%s: %d\n","us500",$us500) if defined ($debug);
        printf("%s: %d\n","us1000",$us1000) if defined ($debug);
        printf("%s: %d\n","us5000",$us5000) if defined ($debug);
        printf("%s: %d\n","us10000",$us10000) if defined ($debug);
        printf("%s: %d\n","us50000",$us50000) if defined ($debug);
        printf("%s: %d\n","us100000",$us100000) if defined ($debug);
        printf("%s: %d\n","us500000",$us500000) if defined ($debug);
        printf("%s: %d\n","us1000000",$us1000000) if defined ($debug);
        printf("%s: %d\n","avgall",$avgall) if defined ($debug);
     # DEBUG END

   # PRINT TITLES
      if ( $first==1 ) {
        printf("         ");
        printf("%5s ", "s_KB"); printf("%s",$SEP);
        printf("%5s ", "thrds"); printf("%s",$SEP);
        printf("%5s ", "mn_ms"); printf("%s",$SEP);
        printf("%6s ", "avg_ms"); printf("%s",$SEP);
        printf("%7s ", "max_ms"); printf("%s",$SEP);
        printf("%4s ", "r_KB"); printf("%s",$SEP);
        printf("%7s ", "s_MB/s" ); printf("%s",$SEP);
        printf("%7s ", "r_MB/s" ); printf("%s",$SEP);
        printf("  ");
        printf("%5s ", "<100u"); printf("%s",$SEP);
        printf("%5s ", "<500u"); printf("%s",$SEP);
        printf("%5s ", "<1ms"); printf("%s",$SEP);
        printf("%5s ", "<5ms"); printf("%s",$SEP);
        printf("%5s ", "<10ms"); printf("%s",$SEP);
        printf("%5s ", "<50ms"); printf("%s",$SEP);
        printf("%5s ", "<100m"); printf("%s",$SEP);
        printf("%5s ", "<1s"); printf("%s",$SEP);
      # printf("%5s ", ">1s"); printf("%s",$SEP);
        printf("%5s ", "p50"); printf("%s",$SEP);
        printf("%5s ", "p95"); printf("%s",$SEP);
        printf("%5s ", "retrans"); 
        printf("\n");
   # PRINT TITLES END

    # PRINT TCP CONFIG
        $first=0;
        printf(" %40s:  %10d %10d\n", "local_send_size ", $local_send_size, "");
        printf(" %40s:  %10d %10d\n", "local_recv_size ", $local_recv_size, "" );
        printf(" %40s:  %10d %10d\n", "remote_recv_size ", $remote_recv_size, "");
        printf(" %40s:  %10d %10d\n", "remote_send_size ", $remote_send_size, "");
      # printf(" %30s:  %s \n", "mss", $mss);
        printf(" \n");
      }
    # PRINT TCP CONFIG END

   # SUM all HISTOGRAM buckets

      $total_sum= $us10 + $us50 + $us100 + $us500 + $us1000 + $us5000 + $us10000 + $us50000 + $us100000 + $us500000 + $us1000000;

      printf("%8s ",    $message_size);  printf("%s",$SEP);
      printf("%4d ",    $message_size/1024); printf("%s",$SEP);
      printf("%5s ",    $worker);  printf("%s",$SEP);
      printf("%5.2f ",  $minl/1000 );  printf("%s",$SEP);
      printf("%6.2f ",  $avgl/1000) ;   printf("%s",$SEP);# average
      printf("%7.2f ",  $maxl/1000 );  printf("%s",$SEP);
    # printf("%4d ",    $send_size/1024); printf("%s",$SEP);
    # printf("%4d ",    $recv_size/1024); printf("%s",$SEP);
      printf("%4s ",    "0"); printf("%s",$SEP);
      printf("%7.3f  ", $sMBsec); printf("%s",$SEP);          # throughput as total_bytes/(max elapsed time)
    # printf("%7.3f  ", $rMBsec); printf("%s",$SEP);       
    # printf("%7s  ", ""); printf("%s",$SEP);
    #  printf("%7.3f  ", $total_throughput); printf("%s",$SEP); # throughput as sum of throughput of threads
      printf("%7.3f  ", 0); printf("%s",$SEP); 

      if ( $total_sum > 0 ) {
      # printf("%5.2f ", 100*($sum/$total_sum) );  printf("%s",$SEP);
        printf("%5.2f ", 100*(( $us10 + $us50 + $us100)/$total_sum) );  printf("%s",$SEP); 
        printf("%5.2f ", 100*(($us500)/$total_sum) );  printf("%s",$SEP); 
        printf("%5.2f ", 100*(($us1000)/$total_sum) );  printf("%s",$SEP); 
        printf("%5.2f ", 100*(($us5000)/$total_sum) );  printf("%s",$SEP); 
        printf("%5.2f ", 100*(($us10000)/$total_sum) );  printf("%s",$SEP); 
        printf("%5.2f ", 100*(($us50000)/$total_sum) );  printf("%s",$SEP); 
        printf("%5.2f ", 100*(($us100000)/$total_sum) );  printf("%s",$SEP); 
        printf("%5.2f ", 100*(($us500000 + $us1000000)/$total_sum) );  printf("%s",$SEP);;
        printf("%5.2f ", $p50/1000 );  printf("%s",$SEP);
        printf("%5.2f ", $p95/1000 ); printf("%s",$SEP);
        printf("%5d ", $retrans_end-$retrans_beg); printf("%s",$SEP);
     }

      printf("\n"); 

   # RESET VARIABLES
        $bytes=0;
        $nano=0; 
        $message_size=0;
        $local_send_size=0;
        $local_recv_size=0;
        $remote_send_size=0;
        $remote_recv_size=0;
       #$local_send_size=0;
       #$local_send_size=0;
       #$local_send_size=0;
        $avgl=0;
        $maxl=0;
        $minl=0;
        $meanl=0;
        $std=0;
        $p50=0;
        $p95=0;
        $us10=0;
        $us50=0;
        $us100=0;
        $us500=0;
        $us1000=0;
        $us5000=0;
        $us10000=0;
        $us50000=0;
        $us100000=0;
        $us500000=0;
        $us1000000=0;
        $avgl=0;
        $total_bytes=0;
        $total_nano=0;
        $total_throughput=0;
        $worker=0;
        $maxnano=0;
        $avgmsg=0;

    } # end of line=END
 } # end of STDIN

   
printf("at end\n") if defined ($debug);

' $ARGUMENTS  | \
for i in 1; do
 if [ $CLEAN -eq 1 ] ; then
   sed -e 's/ 0.00 /      /g' |\
   sed -e 's/ 0 /   /g' |\
   sed -e 's/ 0.000 /       /g' | \
   sed -e 's/ 0\./  ./g' | \
   cat
 else 
   cat
 fi
done | \
 sort -n | \
 sed -e 's/^..........//g'
#' $ARGUMENTS  



# open solaris stats
#        tcpRetransSegs      =  2525     tcpRetransBytes     =3484231
#        tcpInUnorderSegs    = 49421     tcpInUnorderBytes   =71322692
# LINUX stats
#    1186 segments retransmited
#     573 fast retransmits
#      10 forward retransmits
#     122 retransmits in slow start
#     396 other TCP timeouts
#       2 sack retransmits failed
# HP stats
#      10 data packets (820 bytes) retransmitted
#       6 retransmit timeouts
#       2 out of order packets (264 bytes)
# AIX stats
#  460532 data packets (902304524 bytes) retransmitted
#   20971 path MTU discovery terminations due to retransmits
#  125167 retransmit timeouts
# 1440114 out-of-order packets (168854085 bytes)










