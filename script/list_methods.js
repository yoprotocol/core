const fs = require("fs");

// Load the contract ABI
const abi = JSON.parse(fs.readFileSync("out/yoVault.sol/yoVault.json", "utf-8")).abi;

// Filter non-view methods
const nonViewMethods = abi.filter(
  (item) => item.type === "function" && item.stateMutability !== "view" && item.stateMutability !== "pure",
);

// Print the results
console.log("Non-View Public Methods:");
nonViewMethods.forEach((method) => {
  console.log(`${method.name}(${method.inputs.map((i) => i.type).join(", ")})`);
});
