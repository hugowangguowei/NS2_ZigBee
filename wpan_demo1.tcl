###########################################
#           AODV over 802.15.4            #
#     Copyright (c) 2003 Samsung/CUNY     #
# - - - - - - - - - - - - - - - - - - - - #
#       Prepared by Jianliang Zheng       #
#        (zheng@ee.ccny.cuny.edu)         #
###########################################

# ======================================================================
# Define options
# ======================================================================
set val(chan)           Channel/WirelessChannel    ;# Channel Type
set val(prop)           Propagation/TwoRayGround   ;# radio-propagation model
set val(netif)          Phy/WirelessPhy/802_15_4
set val(mac)            Mac/802_15_4
set val(ifq)            Queue/DropTail/PriQueue    ;# interface queue type 接口队列类型？
set val(ll)             LL                         ;# link layer type  链路层类型
set val(ant)            Antenna/OmniAntenna        ;# antenna model  天线模式/全向天线
set val(ifqlen)         50                         ;# max packet in ifq
set val(nn)             25                         ;# number of mobilenodes
set val(rp)             AODV                       ;# routing protocol  节点路由层设置为按需距离矢量路由协议
set val(x)		50
set val(y)		50

set val(nam)		wpan_demo1.nam
set val(traffic)	ftp                        ;# cbr/poisson/ftp

#read command line arguments 阅读命令行参数？
proc getCmdArgu {argc argv} {
        global val
        for {set i 0} {$i < $argc} {incr i} {
                set arg [lindex $argv $i]
                if {[string range $arg 0 0] != "-"} continue
                set name [string range $arg 1 end]
                set val($name) [lindex $argv [expr $i+1]]
        }
}
getCmdArgu $argc $argv

set appTime1            0.0	;# in seconds 
set appTime2            0.3	;# in seconds 
set appTime3            0.7	;# in seconds 
set stopTime            100	;# in seconds 


# 开始正文部分
# Initialize Global Variables
# 新建一个模拟器
set ns_		[new Simulator]
set tracefd     [open ./wpan_demo1.tr w]
$ns_ trace-all $tracefd
if { "$val(nam)" == "wpan_demo1.nam" } {
        set namtrace     [open ./$val(nam) w]
        $ns_ namtrace-all-wireless $namtrace $val(x) $val(y)
}

$ns_ puts-nam-traceall {# nam4wpan #}		;# inform nam that this is a trace file for wpan (special handling needed)

Mac/802_15_4 wpanNam namStatus on		;# default = off (should be turned on before other 'wpanNam' commands can work)
#Mac/802_15_4 wpanNam ColFlashClr gold		;# default = gold
#Mac/802_15_4 wpanNam NodeFailClr grey		;# default = grey


# For model 'TwoRayGround'
set dist(5m)  7.69113e-06
set dist(9m)  2.37381e-06
set dist(10m) 1.92278e-06
set dist(11m) 1.58908e-06
set dist(12m) 1.33527e-06
set dist(13m) 1.13774e-06
set dist(14m) 9.81011e-07
set dist(15m) 8.54570e-07
set dist(16m) 7.51087e-07
set dist(20m) 4.80696e-07
set dist(25m) 3.07645e-07
set dist(30m) 2.13643e-07
set dist(35m) 1.56962e-07
set dist(40m) 1.20174e-07
Phy/WirelessPhy set CSThresh_ $dist(15m)
Phy/WirelessPhy set RXThresh_ $dist(15m)

# set up topography object
set topo       [new Topography]
$topo load_flatgrid $val(x) $val(y)

# Create God
set god_ [create-god $val(nn)]

set chan_1_ [new $val(chan)]

# configure node
# 定义节点属性（按照上面设定好的值）
$ns_ node-config -adhocRouting $val(rp) \
		-llType $val(ll) \
		-macType $val(mac) \
		-ifqType $val(ifq) \
		-ifqLen $val(ifqlen) \
		-antType $val(ant) \
		-propType $val(prop) \
		-phyType $val(netif) \
		-topoInstance $topo \
		-agentTrace OFF \
		-routerTrace OFF \
		-macTrace ON \
		-movementTrace OFF \
                #-energyModel "EnergyModel" \
                #-initialEnergy 1 \
                #-rxPower 0.3 \
                #-txPower 0.3 \
		-channel $chan_1_ 

#将节点都实例化		
for {set i 0} {$i < $val(nn) } {incr i} {
	set node_($i) [$ns_ node]	
	$node_($i) random-motion 0		;# disable random motion
}

source ./wpan_demo1.scn

# Setup traffic flow between nodes
# 启动节点间信息传递规范

# CBR(Constant Bit Rate)
# 到目前为止并不知道 src dst 这两个参数是哪里来的
proc cbrtraffic { src dst interval starttime } {
   global ns_ node_
   #创建一个UDP Agent
	#UDP（User Data Protocol，用户数据报协议）是与TCP相对应的协议。
	#它是面向非连接的协议，它不与对方建立连接，而是直接就把数据包发送过去！ 
	#UDP适用于一次只传送少量数据、对可靠性要求不高的应用环境。
	#比如，我们经常使用“ping”命令来测试两台主机之间TCP/IP通信是否正常，
	#其实“ping”命令的原理就是向对方主机发送UDP数据包，然后对方主机确认收到数据包，
	#如果数据包是否到达的消息及时反馈回来，那么网络就是通的。
	#例如，在默认状态下，一次“ping”操作发送4个数据包（如图2所示）。
	#大家可以看到，发送的数据包数量是4包，收到的也是4包（因为对方主机收到后会发回一个确认收到的数据包）。
	#这充分说明了UDP协议是面向非连接的协议，没有建立连接的过程。
	#正因为UDP协议没有连接的过程，所以它的通信效果高；但也正因为如此，它的可靠性不如TCP协议高。
   set udp($src) [new Agent/UDP] 
   #将该UDP Agent绑定在 $src 这个节点上
   eval $ns_ attach-agent \$node_($src) \$udp($src)
   #创建一个Null Agent
	#Null 是一种数据接收器，负责接收CBR发送的数据
   set null($dst) [new Agent/Null]
   #将该Null Agent绑定在 $dst节点上 （dst节点只有一个吗？）
   eval $ns_ attach-agent \$node_($dst) \$null($dst)
   #创建一个CBR(constant Bit Rate)流量发生器
   set cbr($src) [new Application/Traffic/CBR]
   #设定分组大小为 70B
   eval \$cbr($src) set packetSize_ 70
   #设定发送间隔为 $interval
   eval \$cbr($src) set interval_ $interval
   eval \$cbr($src) set random_ 0
   #将CBR发生器绑定在 $src 这个节点上
   eval \$cbr($src) attach-agent \$udp($src)
   #将udp和null这两个Agent连接起来
   eval $ns_ connect \$udp($src) \$null($dst)
   $ns_ at $starttime "$cbr($src) start"
}

# 泊松通信？与上面的CBR类似，只是设置更多一些
proc poissontraffic { src dst interval starttime } {
   global ns_ node_
   set udp($src) [new Agent/UDP]
   eval $ns_ attach-agent \$node_($src) \$udp($src)
   set null($dst) [new Agent/Null]
   eval $ns_ attach-agent \$node_($dst) \$null($dst)
   set expl($src) [new Application/Traffic/Exponential]
   eval \$expl($src) set packetSize_ 70
   eval \$expl($src) set burst_time_ 0
   eval \$expl($src) set idle_time_ [expr $interval*1000.0-70.0*8/250]ms	;# idle_time + pkt_tx_time = interval
   eval \$expl($src) set rate_ 250k
   eval \$expl($src) attach-agent \$udp($src)
   eval $ns_ connect \$udp($src) \$null($dst)
   $ns_ at $starttime "$expl($src) start"
}

if { ("$val(traffic)" == "cbr") || ("$val(traffic)" == "poisson") } {
   puts "\nTraffic: $val(traffic)"
   #Mac/802_15_4 wpanCmd ack4data on
   puts [format "Acknowledgement for data: %s" [Mac/802_15_4 wpanCmd ack4data]]
   #设置在不同的时间里的传输速率
   set lowSpeed 0.5ms
   set highSpeed 1.5ms
   Mac/802_15_4 wpanNam PlaybackRate $lowSpeed
   $ns_ at [expr $appTime1+0.1] "Mac/802_15_4 wpanNam PlaybackRate $highSpeed"
   $ns_ at $appTime2 "Mac/802_15_4 wpanNam PlaybackRate $lowSpeed"
   $ns_ at [expr $appTime2+0.1] "Mac/802_15_4 wpanNam PlaybackRate $highSpeed"
   $ns_ at $appTime3 "Mac/802_15_4 wpanNam PlaybackRate $lowSpeed"
   $ns_ at [expr $appTime3+0.1] "Mac/802_15_4 wpanNam PlaybackRate $highSpeed"
   #设置三次通信？
   #eval 命令的用法与java中相同，都是将字符串转换成命令以执行
   eval $val(traffic)traffic 19 6 0.2 $appTime1
   eval $val(traffic)traffic 10 4 0.2 $appTime2
   eval $val(traffic)traffic 3 2 0.2 $appTime3
   Mac/802_15_4 wpanNam FlowClr -p AODV -c tomato
   Mac/802_15_4 wpanNam FlowClr -p ARP -c green
   if { "$val(traffic)" == "cbr" } {
   	set pktType cbr
   } else {
   	set pktType exp
   }
   Mac/802_15_4 wpanNam FlowClr -p $pktType -s 19 -d 6 -c blue
   Mac/802_15_4 wpanNam FlowClr -p $pktType -s 10 -d 4 -c green4
   Mac/802_15_4 wpanNam FlowClr -p $pktType -s 3 -d 2 -c cyan4
   $ns_ at $appTime1 "$node_(19) NodeClr blue"
   $ns_ at $appTime1 "$node_(6) NodeClr blue"
   $ns_ at $appTime1 "$ns_ trace-annotate \"(at $appTime1) $val(traffic) traffic from node 19 to node 6\""
   $ns_ at $appTime2 "$node_(10) NodeClr green4"
   $ns_ at $appTime2 "$node_(4) NodeClr green4"
   $ns_ at $appTime2 "$ns_ trace-annotate \"(at $appTime2) $val(traffic) traffic from node 10 to node 4\""
   $ns_ at $appTime3 "$node_(3) NodeClr cyan3"
   $ns_ at $appTime3 "$node_(2) NodeClr cyan3"
   $ns_ at $appTime3 "$ns_ trace-annotate \"(at $appTime3) $val(traffic) traffic from node 3 to node 2\""
}

proc ftptraffic { src dst starttime } {
   global ns_ node_
   set tcp($src) [new Agent/TCP]
   eval \$tcp($src) set packetSize_ 60
   set sink($dst) [new Agent/TCPSink]
   eval $ns_ attach-agent \$node_($src) \$tcp($src)
   eval $ns_ attach-agent \$node_($dst) \$sink($dst)
   eval $ns_ connect \$tcp($src) \$sink($dst)
   set ftp($src) [new Application/FTP]
   eval \$ftp($src) attach-agent \$tcp($src)
   $ns_ at $starttime "$ftp($src) start"
}

if { "$val(traffic)" == "ftp" } {
   puts "\nTraffic: ftp"
   #Mac/802_15_4 wpanCmd ack4data off
   puts [format "Acknowledgement for data: %s" [Mac/802_15_4 wpanCmd ack4data]]
   set lowSpeed 0.20ms
   set highSpeed 1.5ms
   Mac/802_15_4 wpanNam PlaybackRate $lowSpeed
   $ns_ at [expr $appTime1+0.2] "Mac/802_15_4 wpanNam PlaybackRate $highSpeed"
   $ns_ at $appTime2 "Mac/802_15_4 wpanNam PlaybackRate $lowSpeed"
   $ns_ at [expr $appTime2+0.2] "Mac/802_15_4 wpanNam PlaybackRate $highSpeed"
   $ns_ at $appTime3 "Mac/802_15_4 wpanNam PlaybackRate $lowSpeed"
   $ns_ at [expr $appTime3+0.2] "Mac/802_15_4 wpanNam PlaybackRate 1ms"
   ftptraffic 19 6 $appTime1
   ftptraffic 10 4 $appTime2
   ftptraffic 3 2 $appTime3
   Mac/802_15_4 wpanNam FlowClr -p AODV -c tomato
   Mac/802_15_4 wpanNam FlowClr -p ARP -c green
   Mac/802_15_4 wpanNam FlowClr -p tcp -s 19 -d 6 -c blue
   Mac/802_15_4 wpanNam FlowClr -p ack -s 6 -d 19 -c blue
   Mac/802_15_4 wpanNam FlowClr -p tcp -s 10 -d 4 -c green4
   Mac/802_15_4 wpanNam FlowClr -p ack -s 4 -d 10 -c green4
   Mac/802_15_4 wpanNam FlowClr -p tcp -s 3 -d 2 -c cyan4
   Mac/802_15_4 wpanNam FlowClr -p ack -s 2 -d 3 -c cyan4
   $ns_ at $appTime1 "$node_(19) NodeClr blue"
   $ns_ at $appTime1 "$node_(6) NodeClr blue"
   #该指令发出会使得nam中的节点颜色发生变化，且在下面的说明栏中展示
   $ns_ at $appTime1 "$ns_ trace-annotate \"(at $appTime1) ftp traffic from node 19 to node 6\""
   $ns_ at $appTime2 "$node_(10) NodeClr green4"
   $ns_ at $appTime2 "$node_(4) NodeClr green4"
   $ns_ at $appTime2 "$ns_ trace-annotate \"(at $appTime2) ftp traffic from node 10 to node 4\""
   $ns_ at $appTime3 "$node_(3) NodeClr cyan3"
   $ns_ at $appTime3 "$node_(2) NodeClr cyan3"
   $ns_ at $appTime3 "$ns_ trace-annotate \"(at $appTime3) ftp traffic from node 3 to node 2\""
}

# defines the node size in nam
for {set i 0} {$i < $val(nn)} {incr i} {
	$ns_ initial_node_pos $node_($i) 2
}

# Tell nodes when the simulation ends
for {set i 0} {$i < $val(nn) } {incr i} {
    $ns_ at $stopTime "$node_($i) reset";
}

$ns_ at $stopTime "stop"
$ns_ at $stopTime "puts \"\nNS EXITING...\""
$ns_ at $stopTime "$ns_ halt"

proc stop {} {
    global ns_ tracefd val env
    $ns_ flush-trace
    close $tracefd
    set hasDISPLAY 0
    foreach index [array names env] {
        #puts "$index: $env($index)"
        if { ("$index" == "DISPLAY") && ("$env($index)" != "") } {
                set hasDISPLAY 1
        }
    }
    if { ("$val(nam)" == "wpan_demo1.nam") && ("$hasDISPLAY" == "1") } {
	    exec nam wpan_demo1.nam &
    }
}

puts "\nStarting Simulation..."
$ns_ run
