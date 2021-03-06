/*
 * Copyright IBM Corp All Rights Reserved
 *
 * SPDX-License-Identifier: Apache-2.0
 */

// chaincode 在 devmode下似乎是可以独立编译执行的，但不和channel绑定，也就无法读写 ledger。
// package 也必须是 main。每个chaincode自己就是一个独立的进程 entrypoint。
package main

import (
 	"bytes"
	"fmt"
	"github.com/hyperledger/fabric/core/chaincode/shim"
	"github.com/hyperledger/fabric/protos/peer"
	"encoding/json"
	"strconv"
	"time"
)


// Define the insurance structure, with 2 properties.  Structure tags are used by encoding/json library
type Insurance struct {
	Owner  string `json:"owner"`
	Money string `json:"money"`
}

// Init is called during chaincode instantiation to initialize any
// data. Note that chaincode upgrade also calls this function to reset
// or to migrate data.
// 所有方法的第一个参数都是 stub，stub 实际上是智能合约 API 集合的存根句柄。
func (t *Insurance) Init(stub shim.ChaincodeStubInterface) peer.Response {
	// Get the args from the transaction proposal
	args := stub.GetStringArgs()
	if len(args) != 2 {
		return shim.Error("Incorrect arguments. Expecting owner and money")
	}

	// create new insurance object and marshal it into json.
	insuranceAsBytes, _ := json.Marshal(Insurance{args[0], args[1]})
	// Set up any variables or assets here by calling stub.PutState()

	// We store the key and the value on the ledger
	err := stub.PutState(args[0], insuranceAsBytes)
	if err != nil {
		return shim.Error(fmt.Sprintf("Failed to create asset: %s", args[0]))
	}
	return shim.Success(nil)
}

// 只要不产生 signedTransaction，似乎什么数据都可以放到智能合约里来跑，反正试算不消耗资源。
// 这样可以在智能合约里面做 validation。
// Invoke is called per transaction on the chaincode. Each transaction is
// either a 'get' or a 'set' on the asset created by Init function. The Set
// method may create a new asset by specifying a new key-value pair.
func (t *Insurance) Invoke(stub shim.ChaincodeStubInterface) peer.Response {
	// Extract the function and args from the transaction proposal
	fn, args := stub.GetFunctionAndParameters()

	var result string
	var err error
	// 这个分派的函数参数，是由外部传进来的构造函数实现的。
	if fn == "set" {
		result, err = set(stub, args)
	} else if fn == "getHistory" {
		result, err = getHistory(stub, args)
	} else { // assume 'get' even if fn is nil
		result, err = get(stub, args)
	}
	if err != nil {
		return shim.Error(err.Error())
	}

	// Return the result as success payload
	return shim.Success([]byte(result))
}

// Set stores the asset (both key and value) on the ledger. If the key exists,
// it will override the value with the new one
func set(stub shim.ChaincodeStubInterface, args []string) (string, error) {
	if len(args) != 2 {
		return "", fmt.Errorf("Incorrect arguments. Expecting a key and a value")
	}

	insuranceAsBytes, _ := json.Marshal(Insurance{args[0], args[1]})
	err := stub.PutState(args[0], insuranceAsBytes)
	if err != nil {
		return "", fmt.Errorf("Failed to set asset: %s", args[0])
	}
	return args[1], nil
}

// Get returns the value of the specified asset key
func get(stub shim.ChaincodeStubInterface, args []string) (string, error) {
	if len(args) != 1 {
		return "", fmt.Errorf("Incorrect arguments. Expecting a key")
	}

	value, err := stub.GetState(args[0])
	if err != nil {
		return "", fmt.Errorf("Failed to get asset: %s with error: %s", args[0], err)
	}
	if value == nil {
		return "", fmt.Errorf("Asset not found: %s", args[0])
	}

	return string(value), nil
}

// Get returns the value of the specified asset key
func getHistory(stub shim.ChaincodeStubInterface, args []string) (string, error) {
	if len(args) != 1 {
		return "", fmt.Errorf("Incorrect arguments. Expecting a key")
	}

	resultsIterator, err := stub.GetHistoryForKey(args[0])
	if err != nil {
		return "", fmt.Errorf("Failed to get asset: %s with error: %s", args[0], err)
	}
	if resultsIterator == nil {
		return "", fmt.Errorf("history not found: %s", args[0])
	}

	defer resultsIterator.Close()

	// buffer is a JSON array containing historic values for the marble
	var buffer bytes.Buffer
	buffer.WriteString("[")

	bArrayMemberAlreadyWritten := false
	for resultsIterator.HasNext() {
		response, err := resultsIterator.Next()
		if err != nil {
			return "iterating error", err
		}
		// Add a comma before array members, suppress it for the first array member
		if bArrayMemberAlreadyWritten == true {
			buffer.WriteString(",")
		}
		buffer.WriteString("{\"TxId\":")
		buffer.WriteString("\"")
		buffer.WriteString(response.TxId)
		buffer.WriteString("\"")

		buffer.WriteString(", \"Value\":")
		// if it was a delete operation on given key, then we need to set the
		//corresponding value null. Else, we will write the response.Value
		//as-is (as the Value itself a JSON marble)
		if response.IsDelete {
			buffer.WriteString("null")
		} else {
			buffer.WriteString(string(response.Value))
		}

		buffer.WriteString(", \"Timestamp\":")
		buffer.WriteString("\"")
		buffer.WriteString(time.Unix(response.Timestamp.Seconds, int64(response.Timestamp.Nanos)).String())
		buffer.WriteString("\"")

		buffer.WriteString(", \"IsDelete\":")
		buffer.WriteString("\"")
		buffer.WriteString(strconv.FormatBool(response.IsDelete))
		buffer.WriteString("\"")

		buffer.WriteString("}")
		bArrayMemberAlreadyWritten = true
	}
	buffer.WriteString("]")

	fmt.Printf("- getHistoryForMarble returning:\n%s\n", buffer.String())

	return buffer.String(), nil
}


// 这个main 函数可以说是必须要有的
// main function starts up the chaincode in the container during instantiate
func main() {
	if err := shim.Start(new(Insurance)); err != nil {
		fmt.Printf("Error starting Insurance chaincode: %s", err)
	}
}
