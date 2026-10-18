// Throwaway experiment runner. Uses the exact same pure module as the HTML demo.
// Run: node scripts/evaluate-mental-math-prototype.mjs
import fs from 'node:fs';
import vm from 'node:vm';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const html=fs.readFileSync(path.join(root,'Shared/MentalMathPrototype.html'),'utf8');
const context=vm.createContext({performance});
vm.runInContext(html.match(/<script id="mental-math-core">([\s\S]*?)<\/script>/)[1]+';globalThis.math=MentalMath',context);
const math=context.math;
const fixture=JSON.parse(html.match(/<script id="rate-fixture" type="application\/json">([\s\S]*?)<\/script>/)[1]);
const rates={EUR:1,...fixture.rates};
const result={source:'https://api.frankfurter.dev/v1/latest?base=EUR',date:fixture.date,stats:math.stats,examples:[],benchmarks:[]};
const summarize=rule=>rule?{rule:math.explain(rule),factor:rule.factor,errorPercent:rule.error*100,effort:rule.effort,steps:rule.steps.length,mentalSteps:rule.mentalSteps}:null;
const coins=['JPY','USD','GBP','CHF','CNY','INR','KRW','SEK','THB','TRY','IDR','AUD'];
for(const quote of coins)for(const [from,to,amount] of [['EUR',quote,20],[quote,'EUR',1000]]){
  const rate=rates[to]/rates[from];
  result.examples.push({from,to,rate,amount,exact:amount*rate,easy:summarize(math.adaptive(rate,.02)),accurate:summarize(math.recommend(rate,.01))});
}
const currencies=Object.keys(rates);
const pairs=[];
for(const from of currencies)for(const to of currencies)if(from!==to)pairs.push({from,to,rate:rates[to]/rates[from]});
const start=performance.now();
for(const tolerance of [.01,.02,.03])for(const maxMentalSteps of [1,2,3]){
  const chosen=pairs.map(pair=>math.choose(pair.rate,tolerance,maxMentalSteps));
  const found=chosen.filter(Boolean);
  const errors=found.map(rule=>Math.abs(rule.error)*100).sort((a,b)=>a-b);
  result.benchmarks.push({tolerancePercent:tolerance*100,maxMentalSteps,pairs:pairs.length,found:found.length,coveragePercent:found.length/pairs.length*100,medianErrorPercent:errors[Math.floor(errors.length/2)],worstErrorPercent:errors.at(-1),withinEffort3:found.filter(rule=>rule.effort<=3).length,maxSteps:Math.max(...found.map(rule=>rule.steps.length))});
}
result.stats.allPairsSweepMs=performance.now()-start;
result.defaultRules=pairs.map(pair=>({...pair,...summarize(math.recommend(pair.rate,.02))}));
result.defaultSummary={
  found:result.defaultRules.filter(rule=>rule.rule).length,
  twoOperations:result.defaultRules.filter(rule=>rule.mentalSteps<=2).length,
  hardest:result.defaultRules.toSorted((a,b)=>b.effort-a.effort).slice(0,10),
};
result.adaptiveRules=pairs.map(pair=>({...pair,...summarize(math.adaptive(pair.rate,.02))}));
result.adaptiveSummary={found:result.adaptiveRules.filter(rule=>rule.rule).length,
    within2Percent:result.adaptiveRules.filter(rule=>Math.abs(rule.errorPercent)<=2).length,
    within3Percent:result.adaptiveRules.filter(rule=>Math.abs(rule.errorPercent)<=3).length,
    maxErrorPercent:Math.max(...result.adaptiveRules.map(rule=>Math.abs(rule.errorPercent))),
    maxEffort:Math.max(...result.adaptiveRules.map(rule=>rule.effort)),
    twoOperations:result.adaptiveRules.filter(rule=>rule.mentalSteps<=2).length,
    medianErrorPercent:result.adaptiveRules.map(rule=>Math.abs(rule.errorPercent)).sort((a,b)=>a-b)[Math.floor(pairs.length/2)],
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
console.table(result.examples.map(row=>({pair:`${row.from}→${row.to}`,rate:row.rate.toPrecision(7),easy:row.easy?.rule,error:row.easy?.errorPercent.toFixed(3)+'%',precise:row.accurate?.rule,preciseError:row.accurate?.errorPercent.toFixed(3)+'%'})));
console.table(result.benchmarks);console.table(result.grid);
console.log('Full results: build/MentalMath/evaluation.json');
