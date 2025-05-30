    
    
    
//     contract MockERC20{
//         address erc20;
//     constructor(address _erc20) public{
//         erc20 = _erc20;
//     }
//     // function transferFrom(address _to,uint256 _amount) public returns(bool){
//     //   bytes32 a =  keccak256("transferFrom(address,address,uint256)");
//     //   bytes4 methodId = bytes4(a);
//     //   bytes memory b =  abi.encodeWithSelector(methodId,msg.sender,_to,_amount);
//     //   (bool result,) = erc20.call(b);
//     //   return result;
//     // }

// //     function transferFrom(address from, address to, uint256 amount) public returns (bool) {
// //     require(from != address(0), "ERC20: transfer from the zero address");
// //     require(to != address(0), "ERC20: transfer to the zero address");

// //     uint256 senderAllowance = allowance[from][msg.sender];
// //     require(senderAllowance >= amount, "ERC20: transfer amount exceeds allowance");

// //     uint256 senderBalance = balanceOf[from];
// //     require(senderBalance >= amount, "ERC20: transfer amount exceeds balance");

// //     _transfer(from, to, amount);
// //     _approve(from, msg.sender, senderAllowance - amount);

// //     return true;
// // }

//     }
contract Test1 {
    address erc20;

    constructor(address _erc20) public {
        erc20 = _erc20;
    }

    function transferFrom(address _to, uint256 _amount) public returns (bool) {
        bytes32 a = keccak256("transferFrom(address,address,uint256)");
        bytes4 methodId = bytes4(a);
        
        // 编码参数
        bytes memory b = abi.encodeWithSelector(methodId, msg.sender, _to, _amount);

        // 执行目标 ERC20 合约的 transferFrom 函数
        (bool result, bytes memory data) = erc20.call(b);

        // 确保调用成功
        require(result, "Transfer failed");

        return result;
    }
}
