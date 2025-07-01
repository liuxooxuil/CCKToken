// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.0;

// import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// contract USDTTransfer {
//     address public usdtToken;

//     constructor(address _usdtToken) {
//         usdtToken = _usdtToken;
//     }

//     function transferUSDT(address recipient, uint256 amount) public {
//         require(amount > 0, "Amount must be greater than 0");
//         require(IERC20(usdtToken).balanceOf(msg.sender) >= amount, "Insufficient balance");

//         // 从调用者转移 USDT 到接收者
//         IERC20(usdtToken).transferFrom(msg.sender, recipient, amount);
//     }

//     function withdrawUSDT(uint256 amount) external {
//         require(IERC20(usdtToken).balanceOf(address(this)) >= amount, "Insufficient contract balance");
//         // 从合约中提取 USDT
//         IERC20(usdtToken).transfer(msg.sender, amount);
//     }
// }