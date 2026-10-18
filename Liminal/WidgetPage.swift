import SwiftUI

/// The page that draws Lithium's charts and calculators inside an answer, the same way as on the web.
enum WidgetPage {
    static let template = #"""
<!DOCTYPE html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><style>
:root{--bg:#F5F5F7;--raised:#FFFFFF;--sunk:#EDEDF0;--ink:#1D1D1F;--ink-2:#48484A;--ink-3:#6E6E73;--line:#D8D8DD;--line-2:#C4C4C9;--sel:rgba(0,0,0,.08);--font-ui:-apple-system,system-ui,sans-serif;--font-display:-apple-system,system-ui,sans-serif;color-scheme:light dark}
@media (prefers-color-scheme: dark){:root{--bg:#1C1C1E;--raised:#2C2C2E;--sunk:#242426;--ink:#F5F5F7;--ink-2:#C7C7CC;--ink-3:#98989D;--line:#38383A;--line-2:#48484A;--sel:rgba(255,255,255,.1)}}
html,body{margin:0;background:var(--bg);color:var(--ink);font:15px/1.45 var(--font-ui);-webkit-text-size-adjust:100%}
.input{width:100%;box-sizing:border-box;border:1px solid var(--line-2);background:var(--bg);color:var(--ink);border-radius:10px;padding:8px 10px;font:inherit}
.tbl{border-collapse:collapse;width:100%;font-size:13px}.tbl th,.tbl td{border-bottom:1px solid var(--line);padding:5px 6px;text-align:left}.tbl .num{text-align:right}
.pulse{width:10px;height:10px;border-radius:50%;background:#FEBC2E}
.code pre{white-space:pre-wrap;font:12px ui-monospace,monospace}
.wg{--s1:#2a78d6;--s2:#eb6834;--s3:#1baf7a;--s4:#eda100;--s5:#e87ba4;--s6:#008300;margin:10px 0;border:1px solid var(--line);border-radius:14px;background:var(--raised);padding:12px 14px;overflow:hidden}
@media (prefers-color-scheme: dark){:root:not([data-theme="light"]) .wg{--s1:#3987e5;--s2:#d95926;--s3:#199e70;--s4:#c98500;--s5:#d55181;--s6:#008300}}
:root[data-theme="dark"] .wg{--s1:#3987e5;--s2:#d95926;--s3:#199e70;--s4:#c98500;--s5:#d55181;--s6:#008300}
.wg-wait{display:flex;align-items:center;gap:10px;color:var(--ink-2);font-size:.9em}
.wg-h{display:flex;align-items:center;gap:8px;margin-bottom:8px;font-size:.92em}
.wg-h b{font-weight:600}
.wg-chart svg{width:100%;height:auto;display:block;overflow:visible}
.wg-grid{stroke:var(--line);stroke-width:1}.wg-grid.zero{stroke:var(--line-2)}
.wg-ax{font:11px var(--font-ui);fill:var(--ink-3)}
.wg-tot{font:600 22px var(--font-display);fill:var(--ink)}
.wg-bar:hover,.wg-pie path:hover{opacity:.82}
.wg-dot:hover{r:6}
.wg-legend{display:flex;flex-wrap:wrap;gap:6px 14px;font-size:.82em;color:var(--ink-2);margin:0 0 6px}
.wg-legend span{display:inline-flex;align-items:center;gap:6px}
.wg-legend i{width:10px;height:10px;border-radius:3px;display:inline-block;flex:none}
.wg-legend.col{flex-direction:column;gap:7px;justify-content:center}
.wg-legend.col b{margin-left:auto;padding-left:12px;font-weight:600;color:var(--ink);font-variant-numeric:tabular-nums}
.wg-pie{display:grid;grid-template-columns:minmax(150px,220px) minmax(0,1fr);gap:18px;align-items:center}
@media (max-width:520px){.wg-pie{grid-template-columns:1fr}.wg-pie svg{max-width:220px;margin:0 auto}}
.wg-data{margin-top:8px;font-size:.84em}
.wg-data summary{cursor:pointer;color:var(--ink-3);width:fit-content}
.wg-data summary:hover{color:var(--ink)}
.wg-data .tbl-wrap{margin-top:8px}
.calc-f{display:grid;grid-template-columns:repeat(auto-fill,minmax(150px,1fr));gap:10px}
.calc-f label{display:flex;flex-direction:column;gap:4px;font-size:.84em;color:var(--ink-2)}
.calc-in{display:flex;align-items:center;gap:6px}
.calc-in .input{height:38px;font-variant-numeric:tabular-nums}
.calc-in small{color:var(--ink-3);white-space:nowrap}
.calc-r{margin-top:12px;border-top:1px solid var(--line);padding-top:10px;display:flex;flex-direction:column;gap:6px}
.calc-r div{display:flex;justify-content:space-between;align-items:baseline;gap:12px;font-size:.92em;color:var(--ink-2)}
.calc-r b{font-weight:600;color:var(--ink);font-variant-numeric:tabular-nums}
.calc-r .main b{font-size:1.25em}
</style></head><body><div id="w"></div><script>
const esc=s=>String(s==null?'':s).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const ic=()=>'';
const wgParse=code=>{try{const j=JSON.parse(code);return j&&typeof j==='object'?j:null;}catch(e){return null;}};
const wgNum=(n,u)=>{const v=Number(n);if(!isFinite(v))return '—';const s=v.toLocaleString('es',{maximumFractionDigits:Math.abs(v)<10?2:Math.abs(v)<1000?1:0,useGrouping:'always'});return u?(/^[$€£]$/.test(u)?u+s:s+' '+u):s;};
const wgShort=n=>{const a=Math.abs(n);return a>=1e9?(n/1e9).toLocaleString('es',{maximumFractionDigits:1})+' mil M':a>=1e6?(n/1e6).toLocaleString('es',{maximumFractionDigits:1})+' M':a>=1e4?(n/1e3).toLocaleString('es',{maximumFractionDigits:1})+' K':n.toLocaleString('es',{maximumFractionDigits:2});};
function wgNice(v){if(v<=0)return 1;const e=Math.pow(10,Math.floor(Math.log10(v))),f=v/e;return(f<=1?1:f<=2?2:f<=2.5?2.5:f<=5?5:10)*e;}
const wgWait=t=>`<div class="wg wg-wait"><span class="pulse"></span>${t}</div>`;
const wgRaw=(name,code)=>`<div class="code"><div class="code-head"><span>${name}</span><button type="button" data-action="copy-code">Copiar</button></div><pre><code>${esc(code)}</code></pre></div>`;
function wgTable(labels,series,unit,pie){
 return `<details class="wg-data"><summary>Ver los datos</summary><div class="tbl-wrap"><table class="tbl"><thead><tr><th></th>${series.map(s=>`<th>${esc(s.name||'Valor')}</th>`).join('')}${pie?'<th>%</th>':''}</tr></thead><tbody>${labels.map((l,i)=>`<tr><td>${esc(l)}</td>${series.map(s=>`<td class="num">${wgNum(s.vals[i],unit)}</td>`).join('')}${pie?`<td class="num">${pie[i]}</td>`:''}</tr>`).join('')}</tbody></table></div></details>`;
}
function chartHTML(code,closed){
 if(!closed)return wgWait('Preparando el gráfico…');
 const j=wgParse(code);
 if(!j||!Array.isArray(j.series)||!j.series.length||!Array.isArray(j.etiquetas)||!j.etiquetas.length)return wgRaw('gráfico',code);
 const kind=/^(torta|pie|dona|donut|pastel)$/i.test(j.tipo)?'pie':/^(l[ií]neas?|line)$/i.test(j.tipo)?'line':'bar';
 let labels=j.etiquetas.slice(0,24).map(x=>String(x).slice(0,28));
 let series=j.series.slice(0,kind==='pie'?1:4).map(s=>({name:String((s&&(s.nombre||s.name))||'').slice(0,40),vals:labels.map((_,i)=>Number(((s&&(s.valores||s.values))||[])[i]))}));
 const unit=String(j.unidad||'').slice(0,8),title=String(j.titulo||'').slice(0,140);
 const head=title?`<div class="wg-h"><b>${esc(title)}</b></div>`:'';
 if(kind==='pie'){
  // parts of a whole: at most six, the rest folded into «Otros»
  let parts=labels.map((l,i)=>({l,v:Math.max(0,series[0].vals[i]||0)})).filter(x=>x.v>0);
  if(parts.length>6){const keep=parts.slice().sort((a,b)=>b.v-a.v).slice(0,5),rest=parts.filter(x=>!keep.includes(x));parts=parts.filter(x=>keep.includes(x)).concat([{l:'Otros',v:rest.reduce((s,x)=>s+x.v,0),other:true}]);}
  const tot=parts.reduce((s,x)=>s+x.v,0);if(!tot)return wgRaw('gráfico',code);
  const cx=110,cy=110,R=100,r=62;let a0=-Math.PI/2;
  const arcs=parts.map((x,i)=>{const a1=a0+x.v/tot*Math.PI*2,big=a1-a0>Math.PI?1:0,p=(rad,ang)=>`${(cx+rad*Math.cos(ang)).toFixed(2)},${(cy+rad*Math.sin(ang)).toFixed(2)}`;
   const d=parts.length===1?`M${cx-R},${cy}A${R},${R} 0 1 1 ${cx+R},${cy}A${R},${R} 0 1 1 ${cx-R},${cy}ZM${cx-r},${cy}A${r},${r} 0 1 0 ${cx+r},${cy}A${r},${r} 0 1 0 ${cx-r},${cy}Z`:`M${p(R,a0)}A${R},${R} 0 ${big} 1 ${p(R,a1)}L${p(r,a1)}A${r},${r} 0 ${big} 0 ${p(r,a0)}Z`;
   a0=a1;return `<path d="${d}" fill="${x.other?'var(--ink-3)':`var(--s${i+1})`}" stroke="var(--raised)" stroke-width="2" fill-rule="evenodd"><title>${esc(x.l)}: ${esc(wgNum(x.v,unit))} (${Math.round(x.v/tot*100)}%)</title></path>`;});
  const pct=parts.map(x=>Math.round(x.v/tot*100)+'%');
  return `<figure class="wg wg-chart">${head}<div class="wg-pie"><svg viewBox="0 0 220 220" role="img" aria-label="${esc(title||'Gráfico de partes')}">${arcs.join('')}<text x="${cx}" y="${cy-4}" text-anchor="middle" class="wg-tot">${esc(wgShort(tot))}</text><text x="${cx}" y="${cy+14}" text-anchor="middle" class="wg-ax">${esc(unit||'total')}</text></svg><div class="wg-legend col">${parts.map((x,i)=>`<span><i style="background:${x.other?'var(--ink-3)':`var(--s${i+1})`}"></i>${esc(x.l)}<b>${pct[i]}</b></span>`).join('')}</div></div>${wgTable(parts.map(x=>x.l),[{name:series[0].name||'Valor',vals:parts.map(x=>x.v)}],unit,pct)}</figure>`;
 }
 const W=innerWidth<560?380:640,H=innerWidth<560?220:250,L=46,Rr=10,T=12,B=34,n=labels.length,k=series.length; // narrow screens draw at their own size, so the text stays readable
 const all=series.flatMap(s=>s.vals).filter(v=>isFinite(v));if(!all.length)return wgRaw('gráfico',code);
 const hi=wgNice(Math.max(0,...all)),lo=Math.min(0,...all)<0?-wgNice(-Math.min(0,...all)):0;
 const y=v=>T+(hi-v)/(hi-lo)*(H-T-B),plotW=W-L-Rr,band=plotW/n;
 let g='';
 for(let t=0;t<=4;t++){const v=lo+(hi-lo)*t/4,yy=y(v).toFixed(1);g+=`<line x1="${L}" x2="${W-Rr}" y1="${yy}" y2="${yy}" class="wg-grid${v===0?' zero':''}"/><text x="${L-8}" y="${(+yy+4).toFixed(1)}" text-anchor="end" class="wg-ax">${esc(wgShort(v))}</text>`;}
 const every=Math.ceil(n/(innerWidth<560?5:9));
 labels.forEach((l,i)=>{if(i%every)return;const x=kind==='bar'?L+band*i+band/2:L+(n===1?plotW/2:plotW*i/(n-1));g+=`<text x="${x.toFixed(1)}" y="${H-B+18}" text-anchor="middle" class="wg-ax">${esc(l.length>11?l.slice(0,10)+'…':l)}</text>`;});
 let marks='';
 if(kind==='bar'){
  const group=band*.74,bw=Math.max(2,(group-(k-1)*2)/k);
  series.forEach((s,si)=>s.vals.forEach((v,i)=>{if(!isFinite(v))return;const x=L+band*i+(band-group)/2+si*(bw+2),y0=y(0),y1=y(v),h=Math.abs(y1-y0),rr=Math.min(4,bw/2,h),top=Math.min(y0,y1);
   const d=v>=0?`M${x},${y0}V${y1+rr}Q${x},${y1} ${x+rr},${y1}H${x+bw-rr}Q${x+bw},${y1} ${x+bw},${y1+rr}V${y0}Z`:`M${x},${y0}V${y1-rr}Q${x},${y1} ${x+rr},${y1}H${x+bw-rr}Q${x+bw},${y1} ${x+bw},${y1-rr}V${y0}Z`;
   marks+=`<path d="${d}" fill="var(--s${si+1})" class="wg-bar"><title>${esc((s.name?s.name+' · ':'')+labels[i])}: ${esc(wgNum(v,unit))}</title></path>`;void top;}));
 }else{
  const xs=i=>L+(n===1?plotW/2:plotW*i/(n-1));
  series.forEach((s,si)=>{const pts=s.vals.map((v,i)=>isFinite(v)?`${xs(i).toFixed(1)},${y(v).toFixed(1)}`:null);let d='',pen=false;pts.forEach(pt=>{if(!pt){pen=false;return;}d+=(pen?'L':'M')+pt;pen=true;});
   marks+=`<path d="${d}" fill="none" stroke="var(--s${si+1})" stroke-width="2" stroke-linejoin="round" stroke-linecap="round"/>`;
   s.vals.forEach((v,i)=>{if(isFinite(v))marks+=`<circle cx="${xs(i).toFixed(1)}" cy="${y(v).toFixed(1)}" r="${n>14?3:4}" fill="var(--s${si+1})" stroke="var(--raised)" stroke-width="2" class="wg-dot"><title>${esc((s.name?s.name+' · ':'')+labels[i])}: ${esc(wgNum(v,unit))}</title></circle>`;});});
 }
 const legend=k>1?`<div class="wg-legend">${series.map((s,i)=>`<span><i style="background:var(--s${i+1})"></i>${esc(s.name||'Serie '+(i+1))}</span>`).join('')}</div>`:'';
 return `<figure class="wg wg-chart">${head}${legend}<svg viewBox="0 0 ${W} ${H}" role="img" aria-label="${esc(title||'Gráfico')}">${g}${marks}</svg>${wgTable(labels,series,unit)}</figure>`;
}
/** A small, safe calculator language: numbers, field names, + - * / % ^ ( ) and a few functions. Never eval. */
function calcEval(src,vars){
 const toks=String(src).match(/\d+(?:\.\d+)?(?:e[+-]?\d+)?|[A-Za-z_áéíóúñÁÉÍÓÚÑ][\wáéíóúñÁÉÍÓÚÑ]*|\*\*|[-+*/^%(),]/gi)||[];let i=0;
 const F={min:Math.min,max:Math.max,abs:Math.abs,sqrt:Math.sqrt,floor:Math.floor,ceil:Math.ceil,pow:Math.pow,round:(x,d)=>{const k=Math.pow(10,d||0);return Math.round(x*k)/k;}};
 const peek=()=>toks[i],next=()=>toks[i++];
 const prim=()=>{const t=next();if(t==null)throw 0;if(/^\d/.test(t))return parseFloat(t);if(t==='('){const v=expr();if(next()!==')')throw 0;return v;}
  if(/^[A-Za-z_áéíóúñ]/i.test(t)){if(peek()==='('){next();const args=[];if(peek()!==')'){args.push(expr());while(peek()===','){next();args.push(expr());}}if(next()!==')')throw 0;const f=F[t.toLowerCase()];if(!f)throw 0;return f(...args);}
   if(Object.prototype.hasOwnProperty.call(vars,t))return vars[t];const k=Object.keys(vars).find(x=>x.toLowerCase()===t.toLowerCase());if(k)return vars[k];throw 0;}
  throw 0;};
 const pw=()=>{const b=prim();if(peek()==='^'||peek()==='**'){next();return Math.pow(b,un());}return b;};
 const un=()=>{if(peek()==='-'){next();return -un();}if(peek()==='+'){next();return un();}return pw();};
 const term=()=>{let v=un();while(['*','/','%'].includes(peek())){const o=next(),w=un();v=o==='*'?v*w:o==='/'?v/w:v%w;}return v;};
 const expr=()=>{let v=term();while(peek()==='+'||peek()==='-'){const o=next(),w=term();v=o==='+'?v+w:v-w;}return v;};
 try{const v=expr();return i<toks.length?NaN:v;}catch(e){return NaN;}
}
function calcRun(spec,vals){const vars=Object.assign({},vals);return spec.results.map(r=>{const v=calcEval(r.formula,vars);if(r.id)vars[r.id]=v;return v;});}
const calcFmt=(v,r)=>isFinite(v)?wgNum(Math.round(v*Math.pow(10,r.dec))/Math.pow(10,r.dec),r.unit):'—';
function calcHTML(code,closed){
 if(!closed)return wgWait('Preparando la calculadora…');
 const j=wgParse(code);
 if(!j||!Array.isArray(j.campos)||!Array.isArray(j.resultados)||!j.campos.length||!j.resultados.length)return wgRaw('calculadora',code);
 const fields=j.campos.slice(0,12).map((f,i)=>({id:String((f&&f.id)||'c'+i).replace(/[^\wáéíóúñ]/gi,'').slice(0,30)||'c'+i,label:String((f&&(f.etiqueta||f.label))||'').slice(0,60),value:Number(f&&(f.valor!=null?f.valor:f.value))||0,unit:String((f&&f.unidad)||'').slice(0,8)}));
 const results=j.resultados.slice(0,8).map((r,i)=>({id:String((r&&r.id)||'').replace(/[^\wáéíóúñ]/gi,'').slice(0,30),label:String((r&&(r.etiqueta||r.label))||'Resultado').slice(0,60),formula:String((r&&r.formula)||'').slice(0,300),dec:Math.max(0,Math.min(6,parseInt(r&&r.decimales)||(r&&r.decimales===0?0:2))),unit:String((r&&r.unidad)||'').slice(0,8)}));
 const spec={fields,results},vals={};fields.forEach(f=>{vals[f.id]=f.value;});
 const out=calcRun(spec,vals);
 return `<div class="wg calc-w" data-calc="${esc(JSON.stringify(spec))}">${j.titulo?`<div class="wg-h">${ic('table','sm')}<b>${esc(String(j.titulo).slice(0,120))}</b></div>`:''}<div class="calc-f">${fields.map(f=>`<label><span>${esc(f.label||f.id)}</span><span class="calc-in"><input class="input" type="number" inputmode="decimal" step="any" data-id="${esc(f.id)}" value="${f.value}">${f.unit?`<small>${esc(f.unit)}</small>`:''}</span></label>`).join('')}</div><div class="calc-r">${results.map((r,k)=>`<div class="${k===results.length-1?'main':''}"><span>${esc(r.label)}</span><b data-r="${k}">${calcFmt(out[k],r)}</b></div>`).join('')}</div></div>`;
}
document.addEventListener('input',e=>{
 const box=e.target&&e.target.closest&&e.target.closest('.calc-w');if(!box)return;
 let spec;try{spec=JSON.parse(box.dataset.calc);}catch(x){return;}
 const vals={};box.querySelectorAll('input[data-id]').forEach(inp=>{vals[inp.dataset.id]=parseFloat(String(inp.value).replace(',','.'))||0;});
 calcRun(spec,vals).forEach((v,k)=>{const b=box.querySelector(`[data-r="${k}"]`);if(b)b.textContent=calcFmt(v,spec.results[k]);});
});


const SPEC=__SPEC__;
document.getElementById('w').innerHTML=SPEC.kind==='calc'?calcHTML(SPEC.code,true):chartHTML(SPEC.code,true);
</script></body></html>
"""#
}
