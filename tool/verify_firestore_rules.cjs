const assert = require('node:assert/strict');
const auth = 'http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:signUp?key=demo-api-key';
const base = 'http://127.0.0.1:8080/v1/projects/demo-keepy-mp3/databases/(default)/documents';
async function create() {
  const res = await fetch(auth, {method:'POST', headers:{'Content-Type':'application/json'}, body:JSON.stringify({email:'rules-'+crypto.randomUUID()+'@example.test', password:'temp-pass-1234', returnSecureToken:true})});
  assert.equal(res.status,200);
  return res.json();
}
async function firestore(method, url, token) {
  return fetch(base+url, {method, headers:{'Content-Type':'application/json', ...(token ? {Authorization:'Bearer '+token} : {})}, ...(method==='PATCH' ? {body:JSON.stringify({fields:{title:{stringValue:'rules test'}}})} : {})});
}
(async()=>{
  const [a,b]=await Promise.all([create(), create()]);
  const collection='/users/'+a.localId+'/tasks';
  const doc=collection+'/rules-test';
  for (const [method,path,status,token] of [
    ['PATCH',doc,200,a.idToken], ['GET',doc,200,a.idToken], ['GET',collection,200,a.idToken],
    ['GET',doc,403,b.idToken], ['GET',collection,403,b.idToken], ['PATCH',doc,403,b.idToken],
    ['DELETE',doc,403,b.idToken], ['GET',doc,403], ['PATCH',doc,403], ['DELETE',doc,200,a.idToken],
    ['GET',doc,404,a.idToken],
  ]) {
    const res=await firestore(method,path,token);
    assert.equal(res.status,status,method+' expected '+status+' but got '+await res.text());
  }
  const stale = await firestore('PATCH',doc+'?currentDocument.exists=true',a.idToken);
  assert.equal(stale.status,404);
  console.log('Firestore emulator: 12 owner/foreign/unauthenticated/stale-update assertions passed');
})().catch(error=>{console.error(error);process.exitCode=1});
