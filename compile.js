const solc = require('solc');
const fs = require('fs');

const src = fs.readFileSync('contract/AgentPay.sol', 'utf8');
const input = {
  language: 'Solidity',
  sources: { 'AgentPay.sol': { content: src } },
  settings: {
    optimizer: { enabled: true, runs: 200 },
    evmVersion: 'shanghai',
    outputSelection: { '*': { '*': ['evm.bytecode.object', 'abi'] } },
  },
};
const out = JSON.parse(solc.compile(JSON.stringify(input)));
if (out.errors) {
  for (const e of out.errors) console.error(e.formattedMessage);
  if (out.errors.some(e => e.severity === 'error')) process.exit(1);
}
const c = out.contracts['AgentPay.sol']['AgentPay'];
fs.writeFileSync('out_AgentPay_bytecode.hex', '0x' + c.evm.bytecode.object);
fs.writeFileSync('out_AgentPay_abi.json', JSON.stringify(c.abi, null, 2));
console.log('bytecode bytes:', (c.evm.bytecode.object.length / 2) | 0, '| abi entries:', c.abi.length);
