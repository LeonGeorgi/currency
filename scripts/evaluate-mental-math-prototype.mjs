// Throwaway experiment runner. Uses the exact same pure module as the HTML demo.
// Run: node scripts/evaluate-mental-math-prototype.mjs
import fs from 'node:fs';
import vm from 'node:vm';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import assert from 'node:assert/strict';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const html=fs.readFileSync(path.join(root,'Shared/MentalMathPrototype.html'),'utf8');
const context=vm.createContext({performance});
vm.runInContext(html.match(/<script id="mental-math-core">([\s\S]*?)<\/script>/)[1]+';globalThis.math=MentalMath',context);
const math=context.math;
const fixture=JSON.parse(html.match(/<script id="rate-fixture" type="application\/json">([\s\S]*?)<\/script>/)[1]);
const rates={EUR:1,...fixture.rates};
const result={source:'https://api.frankfurter.dev/v1/latest?base=EUR',date:fixture.date,stats:math.stats,weights:math.weights,examples:[],benchmarks:[]};
const summarize=rule=>rule?{rule:math.explain(rule),factor:rule.factor,errorPercent:rule.error*100,effort:math.difficulty(rule).score,difficulty:math.difficulty(rule),primitiveSteps:rule.primitiveSteps,retained:rule.retained,steps:math.trace(rule,1).length,mentalSteps:rule.mentalSteps}:null;
const coins=['JPY','USD','GBP','CHF','CNY','INR','KRW','SEK','THB','TRY','IDR','AUD'];
for(const quote of coins)for(const [from,to,amount] of [['EUR',quote,20],[quote,'EUR',1000]]){
  const rate=rates[to]/rates[from];
  const easy=math.adaptive(rate,.02),accurate=math.recommend(rate,.01);
  result.examples.push({from,to,rate,amount,exact:amount*rate,easy:summarize(easy),easyInverse:summarize(math.inverse(easy,1/rate)),accurate:summarize(accurate),accurateInverse:summarize(math.inverse(accurate,1/rate))});
}
const currencies=Object.keys(rates);
const pairs=[];
for(const from of currencies)for(const to of currencies)if(from!==to)pairs.push({from,to,rate:rates[to]/rates[from]});
const start=performance.now();
for(const tolerance of [.01,.02,.03,.05])for(const maxPrimitiveSteps of [2,3,4,5,6]){
  const chosen=pairs.map(pair=>math.choose(pair.rate,tolerance,3,maxPrimitiveSteps));
  const found=chosen.filter(Boolean);
  const errors=found.map(rule=>Math.abs(rule.error)*100).sort((a,b)=>a-b);
  result.benchmarks.push({tolerancePercent:tolerance*100,maxPrimitiveSteps,pairs:pairs.length,found:found.length,coveragePercent:found.length/pairs.length*100,medianErrorPercent:errors[Math.floor(errors.length/2)]??null,worstErrorPercent:errors.at(-1)??null,maxDisplayedSteps:found.length?Math.max(...found.map(rule=>math.trace(rule,1).length)):0});
}
result.stats.allPairsSweepMs=performance.now()-start;
result.defaultRules=pairs.map(pair=>({...pair,...summarize(math.recommend(pair.rate,.02))}));
result.defaultSummary={
  found:result.defaultRules.filter(rule=>rule.rule).length,
  twoOperations:result.defaultRules.filter(rule=>rule.mentalSteps<=2).length,
  hardest:result.defaultRules.filter(rule=>rule.rule).toSorted((a,b)=>b.effort-a.effort).slice(0,10),
};
result.adaptiveRules=pairs.map(pair=>({...pair,...summarize(math.adaptive(pair.rate,.02))}));
const adaptiveFound=result.adaptiveRules.filter(rule=>rule.rule);
result.adaptiveSummary={found:adaptiveFound.length,missing:pairs.length-adaptiveFound.length,
    within2Percent:adaptiveFound.filter(rule=>Math.abs(rule.errorPercent)<=2).length,
    within3Percent:adaptiveFound.filter(rule=>Math.abs(rule.errorPercent)<=3).length,
    maxErrorPercent:Math.max(...adaptiveFound.map(rule=>Math.abs(rule.errorPercent))),
    maxPrimitiveSteps:Math.max(...adaptiveFound.map(rule=>rule.primitiveSteps)),
    medianErrorPercent:adaptiveFound.map(rule=>Math.abs(rule.errorPercent)).sort((a,b)=>a-b)[Math.floor(adaptiveFound.length/2)],
};
result.pairedRules=pairs.map(pair=>{
  const own=math.adaptive(pair.rate,.02),opposite=math.adaptive(1/pair.rate,.02);
  return {...pair,independentlyEasy:summarize(own),inverseOfOpposite:summarize(math.inverse(opposite,pair.rate))};
});
const pairedFound=result.pairedRules.filter(pair=>pair.independentlyEasy||pair.inverseOfOpposite);
result.pairedSummary={independentlyEasy:adaptiveFound.length,availableWithInverses:pairedFound.length,
  inverseOnly:pairedFound.filter(pair=>!pair.independentlyEasy).length,missing:pairs.length-pairedFound.length,
  inversesOutside3Percent:result.pairedRules.filter(pair=>pair.inverseOfOpposite&&Math.abs(pair.inverseOfOpposite.errorPercent)>3+1e-10).length,
  worstInverseErrorPercent:Math.max(...result.pairedRules.flatMap(pair=>pair.inverseOfOpposite?[Math.abs(pair.inverseOfOpposite.errorPercent)]:[])),
};
result.synthetic=[];
for(const rate of [1,180,1/180,1.125,Math.PI,1e-6,1e6]){
  const rule=math.choose(rate,.03);
  result.synthetic.push({rate,...summarize(rule),traceFor20:rule?math.trace(rule,20):null});
}
// A rate-independent relative error also applies to different amounts, as long as
// intermediate operations aren't rounded. Compare the actual step execution.
let maxTraceResidual=0;
for(const {rate} of pairs){
  const rule=math.choose(rate,.03);
  if(!rule)continue;
  for(const amount of [0,.01,1,5,19.99,100,9999]){
    const trace=math.trace(rule,amount);
    const actual=trace.length?trace.at(-1).value:amount;
    const expected=amount*rule.factor;
    maxTraceResidual=Math.max(maxTraceResidual,Math.abs(actual-expected)/Math.max(1,Math.abs(expected)));
  }
}
result.stats.maxRelativeTraceResidual=maxTraceResidual;
// Check inverses without applying the easy-search budget: each must reverse the
// actual instructions, preserve the rational reciprocal, and report its own error.
let inverseRules=0,roundTrips=0,maxRoundTripResidual=0,maxInverseErrorResidual=0;
const execute=(rule,amount)=>math.trace(rule,amount).at(-1)?.value??amount;
for(const {rate} of [...pairs,...[1,180,1/180,1e-8,1e8].map(rate=>({rate}))]){
  for(const rule of [math.adaptive(rate,.02),math.recommend(rate,.01)]){
    if(!rule)continue;
    const inverse=math.inverse(rule,1/rate);
    for(const candidate of [rule,inverse]){
      const rating=math.difficulty(candidate);
      assert.ok(Number.isFinite(rating.score)&&rating.score>=0,'Every rule and inverse must have a finite difficulty');
      assert.equal(rating.score,rating.operationScore+rating.memoryScore);
      assert.equal(rating.score,rating.breakdown.reduce((sum,step)=>sum+step.parts.reduce((subtotal,part)=>subtotal+part.points,0),0));
      assert.equal(candidate.effort,rating.score,'Selection and displayed difficulty must use the same weights');
    }
    inverseRules++;
    assert.equal(inverse.numerator,rule.denominator);
    assert.equal(inverse.denominator,rule.numerator);
    const errorResidual=Math.abs(inverse.error-(-rule.error/(1+rule.error)));
    maxInverseErrorResidual=Math.max(maxInverseErrorResidual,errorResidual);
    assert.ok(errorResidual<1e-12,'Reciprocal market error must be recomputed');
    for(const amount of [0,.01,1,5,19.99,100,9999]){
      const forward=execute(rule,amount),back=execute(inverse,forward);
      const residual=Math.abs(back-amount)/Math.max(1,Math.abs(amount));
      maxRoundTripResidual=Math.max(maxRoundTripResidual,residual);roundTrips++;
      assert.ok(residual<1e-12,'Inverse instructions must undo the forward instructions');
      assert.ok(Math.abs(execute(inverse,amount)-amount*inverse.factor)/Math.max(1,Math.abs(amount*inverse.factor))<1e-12);
    }
  }
}
result.inverseChecks={inverseRules,roundTrips,maxRoundTripResidual,maxInverseErrorResidual};
const subtractTen=math.operations.find(step=>step.short==='−10%');
assert.equal(math.explain(math.inverse({factor:.9,numerator:9,denominator:10,steps:[subtractTen]},1/.9)),'×10 → ÷9');
assert.ok(math.inverse(math.adaptive(.9272,.02),1/.9272).error>.03,'Forward 3% tolerance does not transfer to inverse');
assert.ok(math.inverse(math.adaptive(7.524,.02),1/7.524),'Every forward rule still needs its counter-rule');
result.directMultipliers=[];
for(let factor=3;factor<=10;factor++){
  const direct=factor===10?math.recommend(10,0):math.operations.find(step=>step.direct&&step.n===factor);
  const rule=factor===10?direct:{factor,numerator:factor,denominator:1,steps:[direct],effort:math.difficulty({steps:[direct]}).score,primitiveSteps:1,retained:1,error:0};
  assert.ok(direct,`Direct ×${factor} must exist`);
  assert.equal(math.trace(rule,19.99).at(-1).value,19.99*factor);
  const inverse=math.inverse(rule,1/factor);
  const decomposition=math.choose(factor,0,3,4,false);
  for(const amount of [0,.01,1,5,19.99,100,9999]){
    assert.ok(Math.abs(execute(inverse,execute(rule,amount))-amount)/Math.max(1,Math.abs(amount))<1e-12);
    if(decomposition)assert.ok(Math.abs(execute(decomposition,amount)-amount*factor)/Math.max(1,Math.abs(amount*factor))<1e-12);
  }
  result.directMultipliers.push({factor,direct:summarize(rule),preferred:summarize(math.recommend(factor,0)),decomposition:summarize(decomposition),inverse:summarize(inverse)});
}
assert.ok(!math.operations.some(step=>step.kind==='divide'&&step.d>=3),'Hard integer division must not enter the easy vocabulary');
assert.equal(math.recommend(7,0).primitiveSteps,1);
assert.equal(math.explain(math.recommend(7,0)),'×7');
result.rewrites=[];
for(const [label,factor] of [['×5',5],['÷5',.2],['×25',25],['÷25',.04],['×50',50],['÷50',.02],['×4',4],['−50%',.5],['×9',9],['×11',11],['×99',99],['×101',101]]){
  const rule=math.recommend(factor,0);
  assert.ok(rule,`Exact strategy required for ${label}`);
  assert.equal(rule.factor,factor);
  for(const amount of [0,.01,1,5,19.99,100,9999])assert.ok(Math.abs(execute(rule,amount)-amount*factor)/Math.max(1,Math.abs(amount*factor))<1e-12);
  result.rewrites.push({label,...summarize(rule),traceFor19_99:math.trace(rule,19.99)});
}
assert.equal(math.explain(math.recommend(5,0)),'halve → ×10');
assert.equal(math.explain(math.recommend(.2,0)),'×2 → ÷10');
assert.equal(math.recommend(.5,0).primitiveSteps,1);
const seven=math.recommend(7,0),sevenInverse=math.inverse(seven,1/7);
assert.ok(math.difficulty(sevenInverse).score>math.difficulty(seven).score,'÷7 must be scored harder than ×7');
assert.equal(math.difficulty(math.recommend(5,0)).score,2);
assert.equal(math.difficulty({steps:[subtractTen]}).score,2.5);
assert.equal(math.difficulty({steps:[]}).score,0);
assert.equal(math.difficulty({steps:math.recommend(7,0).steps.concat(math.recommend(7,0).steps)}).score,4);
result.difficultyExamples=[];
for(const [label,rule] of [['Direct ×7',seven],['Direct ÷7',sevenInverse],['Direct ×5',{steps:[math.operations.find(step=>step.direct&&step.n===5)]}],['Halve then ×10',math.recommend(5,0)],['Subtract 10%',{steps:[subtractTen]}],['Undo subtracting 10%',math.inverse({factor:.9,numerator:9,denominator:10,steps:[subtractTen]},1/.9)],['Add 15%',{steps:[math.operations.find(step=>step.short==='+15%')]}]]){
  result.difficultyExamples.push({label,instructions:math.explain(rule),...math.difficulty(rule)});
}
result.grid=[];
for(const tolerance of [.01,.03]){
  let found=0,worstError=0,maxEffort=0;
  for(let i=0;i<1001;i++){
    const rate=10**(-6+12*i/1000),rule=math.choose(rate,tolerance);
    if(rule){found++;worstError=Math.max(worstError,Math.abs(rule.error)*100);maxEffort=Math.max(maxEffort,rule.effort);}
  }
  result.grid.push({cases:1001,tolerancePercent:tolerance*100,found,worstErrorPercent:worstError,maxEffort});
}
const out=path.join(root,'build/MentalMath');fs.mkdirSync(out,{recursive:true});
fs.writeFileSync(path.join(out,'evaluation.json'),JSON.stringify(result,null,2)+'\n');
console.log('Catalogue:',result.stats,'\nRate date:',fixture.date,'Currencies:',currencies.length,'Directed pairs:',pairs.length);
console.table(result.examples.map(row=>({pair:`${row.from}→${row.to}`,rate:row.rate.toPrecision(7),easy:row.easy?.rule,error:row.easy?row.easy.errorPercent.toFixed(3)+'%':'—',precise:row.accurate?.rule,preciseError:row.accurate?row.accurate.errorPercent.toFixed(3)+'%':'—'})));
console.table(result.benchmarks);console.table(result.grid);
console.log('Paired coverage:',result.pairedSummary,'\nInverse checks:',result.inverseChecks);
console.table(result.rewrites.map(({label,rule,primitiveSteps,retained})=>({label,rule,primitiveSteps,retained})));
console.table(result.directMultipliers.map(({factor,direct,preferred,decomposition,inverse})=>({factor,direct:direct.rule,effort:direct.effort,preferred:preferred.rule,alternative:decomposition?.rule,inverse:inverse.rule})));
console.log('Full results: build/MentalMath/evaluation.json');
