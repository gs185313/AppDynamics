#!/usr/bin/expect -f

set timeout 60

# Output file
set outfile "appd_connectivity_report.txt"
set fh [open $outfile "w"]
puts $fh "Server\tConnectivity with \"ncrvoyix.saas.appdynamics.com -Port 443\""

# Ask password once
stty -echo
send_user "Enter password: "
expect_user -re "(.*)\n"
stty echo
send_user "\n"
set password $expect_out(1,string)

set user "opergpc"
set target "ncrvoyix.saas.appdynamics.com"
set port "443"

set hosts {
sun1205 sun1216 sun1256 sun1290 sun1294 sun1317 sun1350 sun1383 sun1384
sun1473 sun1508 sun1586 sun1597 sun1830 sun1880 sun1881 sun1882 sun1884
sun1889 sun2201 sun2202 sun2204 sun2205 sun2206 sun2304 sun2305 sun2306
sun2502 sun2580 sun2581 sun3051 sun3151 SUN3268 sun3582 sun3664 sun3716
sun3717 sun4041 sun4141 sun4146 sun4351 sun4874 sun5556 sun5561 sun5562
sun5901 sun5902 sun5903 sun5904 sun5905 sun5906 sun6468 sun6901 sun6902
sun6903 sun6904 sun6905 sun6906 sun6907 sun1086 sun1089 sun1135 sun1155
sun1207 sun1269 sun1276 sun1277 sun1293 sun1315 sun1316 sun1330 sun1333
sun1340 sun1341 sun1351 sun1395 sun1403 sun1491 sun1501 sun1509 sun1593
sun1824-cd sun1843 sun1880-cd sun1881-cd sun1882-cd sun1884-cd sun1886-cd
sun1887-cd sun1889-cd sun2001 sun2002 sun2004 sun2005 sun2006 sun2104
sun2105 sun2106 sun3665 sun3674 sun3899 sun4340 sun4341 sun4342 sun4343
sun4395 sun4403 sun4584 sun4875 sun5104 sun5105 sun5901-cd sun5902-cd
sun5903-cd sun5904-cd sun5905-cd sun5906-cd sun6467 sun6567 sun6568
sun6901-cd sun6902-cd sun6903-cd sun6904-cd sun6905-cd sun6906-cd
sun6907-cd sun9306
}

foreach host $hosts {

    puts "====================================="
    puts "Checking: $host"

    spawn ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 \
    $user@$host "which nc >/dev/null 2>&1 && nc -z $target $port >/dev/null 2>&1 && echo SUCCESS || echo FAIL"

    expect {
        "*Could not resolve*" {
            puts $fh "$host\tDNS_FAIL"
            puts "$host : DNS_FAIL"
        }

        "*Permission denied*" {
            puts $fh "$host\tAUTH_FAIL"
            puts "$host : AUTH_FAIL"
            catch {close}
            catch {wait}
        }

        "*yes/no*" {
            send "yes\r"
            exp_continue
        }

        -re ".*assword.*" {
            send "$password\r"
            exp_continue
        }

        "*SUCCESS*" {
            puts $fh "$host\tSUCCESS"
            puts "$host : SUCCESS"
        }

        "*FAIL*" {
            puts $fh "$host\tFAIL"
            puts "$host : FAIL"
        }

        timeout {
            puts $fh "$host\tTIMEOUT"
            puts "$host : TIMEOUT"
            catch {close}
            catch {wait}
        }
    }

    # ✅ Prevent expXX "channel not open" errors
    catch {expect eof}
}

close $fh
puts "\n✅ Report generated: $outfile"
