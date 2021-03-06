#!/bin/bash

echo
echo " ____    _____      _      ____    _____ "
echo "/ ___|  |_   _|    / \    |  _ \  |_   _|"
echo "\___ \    | |     / _ \   | |_) |   | |  "
echo " ___) |   | |    / ___ \  |  _ <    | |  "
echo "|____/    |_|   /_/   \_\ |_| \_\   |_|  "
echo
echo "Build fabric custom network end-to-end test"
echo
CHANNEL_NAME="$1"
DELAY="$2"
: ${CHANNEL_NAME:="mychannel"}
: ${TIMEOUT:="60"}
COUNTER=1
MAX_RETRY=5
# 是不是使用 TLS，其实只与 orderer 和 channel 有关。orderer 只有在用到 tls 的时候，才出现 ca 的使用。
ORDERER_CA=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/ORDERER_DOMAIN/orderers/orderer.ORDERER_DOMAIN/msp/tlscacerts/tlsca.ORDERER_DOMAIN-cert.pem

echo "Channel name : "$CHANNEL_NAME

# verify the result of the end-to-end test
verifyResult () {
	if [ $1 -ne 0 ] ; then
		echo "!!!!!!!!!!!!!!! "$2" !!!!!!!!!!!!!!!!"
    echo "========= ERROR !!! FAILED to execute End-2-End Scenario ==========="
		echo
   		exit 1
	fi
}

setGlobals () {

	if [ $1 -eq 0 -o $1 -eq 1 ] ; then
		CORE_PEER_LOCALMSPID="Org1MSP"
		CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/ORG1_DOMAIN/peers/peer0.ORG1_DOMAIN/tls/ca.crt
		CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/ORG1_DOMAIN/users/Admin@ORG1_DOMAIN/msp
		# 传进来不同的命令，更改的核心环境变量指标是容器的 endpoint 地址。也就是CORE_PEER_ADDRESS。相同组织的 enpoint 使用的是相同的 MSP 密码学目录。
		if [ $1 -eq 0 ]; then
			CORE_PEER_ADDRESS=peer0.ORG1_DOMAIN:7051
		else
			CORE_PEER_ADDRESS=peer1.ORG1_DOMAIN:7051
			# 此处有重复，疑为错误。但 github 上原版的代码就是这样写的。
			CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/ORG1_DOMAIN/users/Admin@ORG1_DOMAIN/msp
		fi
	elif [ $1 -eq 2 -o $1 -eq 3 ] ; then
		CORE_PEER_LOCALMSPID="Org2MSP"
		# 共用一个 tls ca
		CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/ORG2_DOMAIN/peers/peer0.ORG2_DOMAIN/tls/ca.crt
		# 共用一个 msp
		CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/ORG2_DOMAIN/users/Admin@ORG2_DOMAIN/msp
		if [ $1 -eq 2 ]; then
			CORE_PEER_ADDRESS=peer0.ORG2_DOMAIN:7051
		else
			CORE_PEER_ADDRESS=peer1.ORG2_DOMAIN:7051
		fi
	else
		CORE_PEER_LOCALMSPID="Org3-MSP"
		CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/ORG3_DOMAIN/peers/peer0.ORG3_DOMAIN/tls/ca.crt
		CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/ORG3_DOMAIN/users/Admin@ORG3_DOMAIN/msp
		if [ $1 -eq 4 ]; then
			CORE_PEER_ADDRESS=peer0.ORG3_DOMAIN:7051
		else
			CORE_PEER_ADDRESS=peer1.ORG3_DOMAIN:7051
		fi
	fi

	env |grep CORE
}

# 创建频道是第一步
createChannel() {
	# 把 cli 内的全局变量设置为0系列
	setGlobals 0

  if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
  		# 1 -o 是 orderer string，实际上就是从cli 容器出发，可以读到的容器地址，这里还要考虑容器网络连通性问题。-c 是频道名。channel.tx是不可读文件。
  		# 换言之，如果我们有足够多的创世区块，和 channel.tx。我们可以在一个 cli 容器里面生成多个频道。
  		# 2 实际上我们从这一步开始，就知道了 orderer 才是最先 join 进这个 channel 里的一个节点。
  		# 3 几乎所有的频道、peer、orderer 节点相关的操作，都要依靠这个 peer channel 命令开头的系列命令。
  		# 4 channel id 就是 channel name。
  		# 5 这一步在 peer 上也可以做，只要能摸到 orderer 就行了。
		peer channel create -o orderer.ORDERER_DOMAIN:7050 -c $CHANNEL_NAME -f ./channel-artifacts/channel.tx >&log.txt
	else
		# 注意，如果需要打开 tls，那么这个--cafile选项特别特别重要。
		peer channel create -o orderer.ORDERER_DOMAIN:7050 -c $CHANNEL_NAME -f ./channel-artifacts/channel.tx --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA >&log.txt
	fi
	res=$?
	cat log.txt
	verifyResult $res "Channel creation failed"
	echo "===================== Channel \"$CHANNEL_NAME\" is created successfully ===================== "
	echo
}

updateAnchorPeers() {
  PEER=$1
  setGlobals $PEER

  if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
  		# 生成的 anchor artifact 到这里才有用。这样才算真的把锚节点注册上去了。
		peer channel update -o orderer.ORDERER_DOMAIN:7050 -c $CHANNEL_NAME -f ./channel-artifacts/${CORE_PEER_LOCALMSPID}anchors.tx >&log.txt
	else
		peer channel update -o orderer.ORDERER_DOMAIN:7050 -c $CHANNEL_NAME -f ./channel-artifacts/${CORE_PEER_LOCALMSPID}anchors.tx --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA >&log.txt
	fi
	res=$?
	cat log.txt
	verifyResult $res "Anchor peer update failed"
	echo "===================== Anchor peers for org \"$CORE_PEER_LOCALMSPID\" on \"$CHANNEL_NAME\" is updated successfully ===================== "
	sleep $DELAY
	echo
}

## Sometimes Join takes time hence RETRY atleast for 5 times
joinWithRetry () {
	# peer channel join 实际上是消耗四个环境变量作为把 peer 加入 channel 的依据，所以外部传进来的环境变量到此几乎可说是无用的。
	# CORE_PEER_MSPCONFIGPATH
	# CORE_PEER_ADDRESS
	# CORE_PEER_LOCALMSPID
	# CORE_PEER_TLS_ROOTCERT_FILE
	peer channel join -b $CHANNEL_NAME.block  >&log.txt
	res=$?
	cat log.txt
	if [ $res -ne 0 -a $COUNTER -lt $MAX_RETRY ]; then
		COUNTER=` expr $COUNTER + 1`
		# 这的 peer 是顺序 peer，和实际的容器名是不一样的。
		echo "PEER$1 failed to join the channel, Retry after 2 seconds"
		# bash sleep 的妙用
		sleep $DELAY
		# 递归重试
		joinWithRetry $1
	else
		COUNTER=1
	fi
  verifyResult $res "After $MAX_RETRY attempts, PEER$ch has failed to Join the Channel"
}

joinChannel () {
	for ch in 0 1 2 3 4 5; do
		setGlobals $ch
		joinWithRetry $ch
		echo "===================== PEER$ch joined on the channel \"$CHANNEL_NAME\" ===================== "
		sleep $DELAY
		echo
	done
}

installChaincode () {
	PEER=$1
	setGlobals $PEER
	# 这里这个 p 就是在cli 容器内可以看到的 chaincode 的 go 文件路径了。n 则是链码的合约名字。
	# 这个链码为什么不需要经过编译，真是奇也怪哉。
	# install 只指定了 peer 节点，没有指定通道，可见安装上去可以在多个通道上初始化和使用。
	peer chaincode install -n mycc -v 1.0 -p github.com/hyperledger/fabric/examples/chaincode/go/chaincode_example02 >&log.txt
	res=$?
	cat log.txt
        verifyResult $res "Chaincode installation on remote peer PEER$PEER has Failed"
	echo "===================== Chaincode is installed on remote peer PEER$PEER ===================== "
	echo
}

instantiateChaincode () {
	PEER=$1
	setGlobals $PEER
	# 用硬编码的方式好过用接口的方式来读写 orderer endpoint 的位置。
	# 奇特的地方是，初始化链码需要 orderer，安装不需要 orderer，在这里 orderer 的含义是什么呢？
	# while 'peer chaincode' command can get the orderer endpoint from the peer (if join was successful),
	# lets supply it directly as we know it using the "-o" option
	if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
		# 在链码初始化的时候，制定背书策略。
		# 供反射调用
		peer chaincode instantiate -o orderer.ORDERER_DOMAIN:7050 -C $CHANNEL_NAME -n mycc -v 1.0 -c '{"Args":["init","a","100","b","200"]}' -P "OR	('Org1MSP.member','Org2MSP.member')" >&log.txt
	else
		# 只有真的初始化 chaincode 的时候，才指定了 orderer 和 channel name。
		peer chaincode instantiate -o orderer.ORDERER_DOMAIN:7050 --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA -C $CHANNEL_NAME -n mycc -v 1.0 -c '{"Args":["init","a","100","b","200"]}' -P "OR	('Org1MSP.member','Org2MSP.member')" >&log.txt
	fi
	res=$?
	cat log.txt
	verifyResult $res "Chaincode instantiation on PEER$PEER on channel '$CHANNEL_NAME' failed"
	echo "===================== Chaincode Instantiation on PEER$PEER on channel '$CHANNEL_NAME' is successful ===================== "
	echo
}

chaincodeQuery () {
  PEER=$1
  echo "===================== Querying on PEER$PEER on channel '$CHANNEL_NAME'... ===================== "
  setGlobals $PEER
  local rc=1
  local starttime=$(date +%s)

  # continue to poll
  # we either get a successful response, or reach TIMEOUT
  while test "$(($(date +%s)-starttime))" -lt "$TIMEOUT" -a $rc -ne 0
  do
     sleep $DELAY
     echo "Attempting to Query PEER$PEER ...$(($(date +%s)-starttime)) secs"
     peer chaincode query -C $CHANNEL_NAME -n mycc -c '{"Args":["query","a"]}' >&log.txt
     test $? -eq 0 && VALUE=$(cat log.txt | awk '/Query Result/ {print $NF}')
     test "$VALUE" = "$2" && let rc=0
  done
  echo
  cat log.txt
  if test $rc -eq 0 ; then
	echo "===================== Query on PEER$PEER on channel '$CHANNEL_NAME' is successful ===================== "
  else
	echo "!!!!!!!!!!!!!!! Query result on PEER$PEER is INVALID !!!!!!!!!!!!!!!!"
        echo "================== ERROR !!! FAILED to execute End-2-End Scenario =================="
	echo
	exit 1
  fi
}

chaincodeInvoke () {
	PEER=$1
	setGlobals $PEER
	# while 'peer chaincode' command can get the orderer endpoint from the peer (if join was successful),
	# lets supply it directly as we know it using the "-o" option
	if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
		# -c 是调用的消息的构造函数的参数。后台基本上是用反射什么的来执行调用的。
		peer chaincode invoke -o orderer.ORDERER_DOMAIN:7050 -C $CHANNEL_NAME -n mycc -c '{"Args":["invoke","a","b","10"]}' >&log.txt
	else
		peer chaincode invoke -o orderer.ORDERER_DOMAIN:7050  --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA -C $CHANNEL_NAME -n mycc -c '{"Args":["invoke","a","b","10"]}' >&log.txt
	fi
	res=$?
	cat log.txt
	verifyResult $res "Invoke execution on PEER$PEER failed "
	echo "===================== Invoke transaction on PEER$PEER on channel '$CHANNEL_NAME' is successful ===================== "
	echo
}

## Create channel
echo "Creating channel..."
createChannel

## Join all the peers to the channel
echo "Having all peers join the channel..."
joinChannel

## Set the anchor peers for each org in the channel
echo "Updating anchor peers for org1..."
# 这两个函数调用，要仔细更改当前的核心环境变量为两个组织预先生成好的 anchor 节点的 endpoint。
updateAnchorPeers 0
echo "Updating anchor peers for org2..."
updateAnchorPeers 2
echo "Updating anchor peers for org3..."
updateAnchorPeers 4

# 只在 peer0 和 peer2上安装合约
## Install chaincode on Peer0/Org1 and Peer2/Org2
echo "Installing chaincode on org1/peer0..."
installChaincode 0
echo "Install chaincode on org2/peer2..."
installChaincode 2
echo "Install chaincode on org3/peer4..."
installChaincode 4
echo "Install chaincode on org3/peer5..."
installChaincode 5

# 只在 peer2上初始化合约
#Instantiate chaincode on Peer2/Org2
echo "Instantiating chaincode on org2/peer2..."
instantiateChaincode 2

# 只在 peer0 上查询合约
#Query on chaincode on Peer0/Org1
echo "Querying chaincode on org1/peer0..."
chaincodeQuery 0 100

# 只在 peer0 上调用合约
#Invoke on chaincode on Peer0/Org1
echo "Sending invoke transaction on org1/peer0..."
chaincodeInvoke 0

# 在 peer3 上追加安装合约 
## Install chaincode on Peer3/Org2
echo "Installing chaincode on org2/peer3..."
installChaincode 3

# 在 peer3 上追加查询合约。可见追加进来的合约调用结果可以被明确查询到。
#Query on chaincode on Peer3/Org2, check if the result is 90
echo "Querying chaincode on org2/peer3..."
chaincodeQuery 3 90

echo "Querying chaincode on org3/peer4..."
chaincodeQuery 4 90
echo "Querying chaincode on org3/peer5..."
chaincodeQuery 5 90

echo
echo "========= All GOOD, execution completed =========== "
echo

echo
echo " _____   _   _   ____   "
echo "| ____| | \ | | |  _ \  "
echo "|  _|   |  \| | | | | | "
echo "| |___  | |\  | | |_| | "
echo "|_____| |_| \_| |____/  "
echo


#while true
#do
#sleep 10000
#echo "继续苟且偷生"
#done



# 因为这里有了exit 0，所以这个进程就结束了，这个进程结束，这个容器也就结束了。
exit 0
# 即使没有这个exit 0，这个进程结束了，容器也就结束了，tty也救不了这个容器，只能输出容器的 console 罢了。再用 docker start 也启动不了这个容器。