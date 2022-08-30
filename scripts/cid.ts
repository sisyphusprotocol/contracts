// import { base64 } from 'multiformats/bases/base64';
import { ethers } from 'hardhat';
import { CID } from 'multiformats/cid';
import * as json from 'multiformats/codecs/json';
import { sha256 } from 'multiformats/hashes/sha2';

async function main() {
  const bytes = json.encode({ hello: 'world' });

  const hash = await sha256.digest(bytes);
  const cid = CID.create(1, json.code, hash);

  /* cspell:disable-next-line */
  const c = CID.parse('bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi');

  console.log(cid, c.toV0());

  console.log(ethers.utils.formatBytes32String('ipfs://1111111111111111111111111'));
}

main().catch((e) => {
  console.error(e);
});
