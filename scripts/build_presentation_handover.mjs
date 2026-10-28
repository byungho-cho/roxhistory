import fs from 'node:fs/promises';
import path from 'node:path';
import {pathToFileURL,fileURLToPath} from 'node:url';
const repo=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const workspaceDir=path.resolve(repo,'../..');
const runtime=process.env.CODEX_PRIMARY_RUNTIME_NODE_MODULES;
if(!runtime)throw new Error('CODEX_PRIMARY_RUNTIME_NODE_MODULES is required');
const {Presentation,PresentationFile}=await import(pathToFileURL(path.join(runtime,'@oai/artifact-tool/dist/artifact_tool.mjs')).href);
const p=Presentation.create({slideSize:{width:1280,height:720}});
const C={bg:'#112D2B',text:'#F6F0E3',muted:'#B9C9BF',gold:'#F0BD6C',line:'#58726A'};
const font='Malgun Gothic';
const source='근거: 사용자 제공 RoxHistory 프로젝트 설계 인수인계 지시, 2026-10-28. 현재 기준 docs/synopsis-v0.1-handover.md. 이전 상세안은 보존하고 재확인 대상으로 구분한다.';
function txt(s,name,value,x,y,w,h,size=28,color=C.text,bold=false){
 const o=s.shapes.add({geometry:'textbox',name,position:{left:x,top:y,width:w,height:h},fill:'none',line:{style:'solid',fill:'none',width:0}});
 o.text=value;o.text.style={fontSize:size,typeface:font,color,bold,autoFit:'none',wrap:'square',insets:0};return o;
}
function sl(i,title){
 const s=p.slides.add();s.background.fill=C.bg;
 if(title)txt(s,'title',title,64,48,1152,74,43,C.text,true);
 txt(s,'page',String(i).padStart(2,'0'),1160,670,56,24,16,C.muted);
 s.speakerNotes.text=source;return s;
}
function note(s,v){s.speakerNotes.text=source+'\n'+v;}
function table(s,vals,widths,y=190,h=350){
 const t=s.tables.add({rows:vals.length,columns:vals[0].length,left:64,top:y,width:1152,height:h,columnWidths:widths,values:vals});
 t.borders.assign({style:'solid',fill:C.line,width:1});
 t.cells.block({row:0,column:0,rowCount:vals.length,columnCount:vals[0].length}).assign({fill:C.bg,textStyle:{typeface:font,fontSize:25,color:C.text},margins:{top:14,bottom:14,left:16,right:16},anchor:'center'});
 t.cells.block({row:0,column:0,rowCount:1,columnCount:vals[0].length}).assign({fill:'#29483F',textStyle:{typeface:font,fontSize:25,color:C.gold,bold:true}});
 return t;
}
function box(s,name,label,x,y,w,h){
 const o=s.shapes.add({geometry:'rect',name,position:{left:x,top:y,width:w,height:h},fill:C.bg,line:{style:'solid',fill:C.line,width:2}});
 o.text=label;o.text.style={typeface:font,fontSize:28,color:C.text,alignment:'center',verticalAlignment:'middle',insets:12};return o;
}
function link(s,a,b){s.shapes.connect(a,b,{kind:'elbow',fromSide:'right',toSide:'left',line:{style:'solid',fill:C.gold,width:2},tail:{type:'triangle',width:'med',length:'med'}});}
{
 const s=sl(1);
 txt(s,'brand','RoxHistory',64,84,1120,110,76,C.gold,true);
 txt(s,'cover-title','지도에서 만나는\n한국 역사의 흐름',64,224,1120,185,62,C.text,true);
 txt(s,'cover-summary','게임을 즐기며 시대의 변화와\n한국 지리를 자연스럽게 이해한다',68,462,1090,110,30,C.muted);
 txt(s,'version','초기 시놉시스 v0.1 인수인계 정합본 · 2026.10.28',68,635,1040,38,22,C.muted);
 note(s,'지도 중심 역사 기반 게임이라는 확정 철학을 소개한다. 장르와 상세 게임 규칙은 미확정이다.');
}
{
 const s=sl(2,'개발 목적과 주요 사용자');
 txt(s,'purpose','세부 암기보다 시대와 지역의 관계를 이해하는 경험',64,139,1152,65,31,C.gold);
 table(s,[['주요 사용자','얻고 싶은 경험'],['중·고등학생','처음 배우는 한국사의 큰 흐름'],['역사를 다시 배우는 성인','나라와 시대, 지역의 관계'],['역사·지리에 관심 있는 사용자','지도와 변화로 이어지는 역사 경험']],[450,702],240,320);
 txt(s,'principle','역사 지식이 부족해도 진입할 수 있는 게임을 지향한다',64,595,1152,62,27,C.muted);
}
{
 const s=sl(3,'핵심 게임 콘셉트');
 const labels=[['지도','한반도와 주변 지역을 중심으로\n역사 진행과 상호작용을 연결한다'],['시간','선사시대부터 주요 시대를 따라\n국가와 세력, 장소의 변화를 접한다'],['플레이','재미를 경험하는 과정에서\n역사와 지리의 맥락이 남도록 한다']];
 labels.forEach((v,i)=>{const y=196+i*138;txt(s,'concept-'+i,v[0],64,y,200,65,40,C.gold,true);txt(s,'concept-body-'+i,v[1],302,y,914,104,31,C.text);});
 note(s,'경험의 방향을 제시한다. 국가 운영·영토 확장·자원 관리·생존 RPG는 여기서 확정하지 않는다.');
}
{
 const s=sl(4,'지도가 연결하는 역사 정보');
 const map=await fs.readFile(path.join(repo,'assets/maps/korea-modern-coast-reference.svg'));
 s.images.add({blob:map.buffer.slice(map.byteOffset,map.byteOffset+map.byteLength),contentType:'image/svg+xml',name:'modern-coast-reference',alt:'현대 해안선 참고도. 역사적 영토 경계는 포함하지 않음',fit:'contain',position:{left:64,top:146,width:626,height:478}});
 [['국가와 세력','등장·발전·소멸과 관계'],['지형과 장소','지역의 위치와 지리적 맥락'],['사건과 변화','시점에 따라 달라지는 지도']].forEach((v,i)=>{const y=189+i*139;txt(s,'map-label-'+i,v[0],740,y,476,52,31,C.gold,true);txt(s,'map-detail-'+i,v[1],740,y+60,476,62,27,C.text);});
 txt(s,'map-disclosure','현대 해안선 참고도 · 역사 지도와 시대별 영역은 후속 고증',64,630,1120,36,22,C.muted);
 note(s,'지도 도형 출처: Natural Earth ne_50m_land.geojson. https://github.com/nvkelso/natural-earth-vector/blob/master/geojson/ne_50m_land.geojson . 이용 조건 https://www.naturalearthdata.com/about/terms-of-use/ . 현대 육지 자료를 120~135E,32~44N으로 잘라 Mercator 투영했다. 역사적 경계나 선사시대 지형을 표현하지 않는다. 이 범위를 최종 게임 지리 범위로 확정하지 않는다.');
}
{
 const s=sl(5,'선사시대부터 현대까지의 흐름');
 const eras=['선사시대','고조선과 초기 국가','삼국시대 및 가야','남북국시대','후삼국과 고려','조선','근대 및 일제강점기','현대 대한민국'];
 eras.forEach((era,i)=>{const col=i<4?0:1,row=i%4,x=64+col*602,y=177+row*105;txt(s,'era-n-'+i,String(i+1).padStart(2,'0'),x,y,72,56,29,C.gold,true);txt(s,'era-'+i,era,x+95,y,455,62,31,C.text,true);});
 txt(s,'era-state','잠정 시대 구분 · 실제 장·스테이지·진행 조건과 분량은 미정',64,622,1152,45,25,C.muted);
 note(s,'사용자가 제시한 잠정 구분을 순서대로 표시했다. 고정 장 수, 시대 전환 사건이나 중간 역사 과정의 생략을 확정하지 않는다.');
}
{
 const s=sl(6,'플레이어 경험의 목표');
 txt(s,'intro','같은 공간에서 이어지는 변화를 경험한다',64,139,1152,60,31,C.gold);
 const labels=['지역을 이해','관계를 파악','변화를 체험','흐름을 연결'];
 const bs=labels.map((v,i)=>box(s,'experience-'+i,v,64+i*296,270,264,100));bs.slice(0,3).forEach((b,i)=>link(s,b,bs[i+1]));
 ['어디에 있는가','무엇과 연결되는가','무엇이 달라졌는가','앞뒤 시대의 관계'].forEach((v,i)=>txt(s,'meaning-'+i,v,64+i*296,407,264,90,25,C.muted));
 txt(s,'pending','기본 반복 행동과 목표·보상은 다음 시스템 설계에서 협의한다',64,585,1152,70,28,C.text);
 note(s,'학습과 경험의 목표를 설명하는 편집 가능한 개념도다. 확정 게임 루프나 지도 클릭만으로 완성되는 게임이라는 뜻은 아니다.');
}
{
 const s=sl(7,'역사 학습과 플레이의 관계');
 table(s,[['플레이에서 접할 변화','자연스럽게 이해할 맥락'],['지역과 장소를 지도에서 접한다','위치와 주변 지리의 관계'],['여러 국가와 세력의 변화를 본다','국가의 등장과 발전, 세력 관계'],['주요 사건과 장소를 연결한다','어디에서 무엇이 달라졌는지'],['앞뒤 시대의 지도를 비교한다','시대의 순서와 큰 전환']],[560,592],179,388);
 txt(s,'learning','맥락에 필요한 핵심부터 제공하고 상세 정보의 양과 방식은 검토한다',64,602,1152,63,25,C.gold);
 note(s,'교육적 설계 목표다. 학습 효과를 실증한 결과가 아니다. 상세 정보 열람 방식과 플레이 조작은 미확정이다.');
}
{
 const s=sl(8,'역사적 사실과 게임적 가정');
 txt(s,'fact-title','역사 자료의 기준',64,174,530,60,32,C.gold,true);
 txt(s,'facts','시점과 출처를 함께 관리\n영토·영향권·문화권을 구분\n논쟁과 불확실성을 표시\n시대별 지형과 정치 변화 검토',64,262,530,260,29,C.text);
 txt(s,'fiction-title','게임 설계의 기준',686,174,530,60,32,C.gold,true);
 txt(s,'fiction','확인된 사실과 가정을 구분\n가상 전개를 실제 역사와 구별\n설명보다 맥락과 경험을 우선\n분기와 선택 규칙은 미확정',686,262,530,260,29,C.text);
 txt(s,'accuracy','고증 전의 영토 도형을 확정된 역사 지도처럼 사용하지 않는다',64,601,1152,61,26,C.muted);
}
{
 const s=sl(9,'기존 상세안과 현재 결정 상태');
 table(s,[['이전 산출물에 남은 내용','현재 처리'],['생존 RPG·사냥·제작·도시 성장','기존 상세안으로 보존, 재확인 필요'],['세 가지 지역 시작 경로','기존 상세안으로 보존, 재확인 필요'],['근현대까지 약 40장','이전 목표 규모, 현재 분량 미정'],['세계 재구성·인물 재선택·계승','기존 상세안으로 보존, 재확인 필요']],[550,602],177,390);
 txt(s,'status','최신 인수인계는 구체 게임 방식과 시스템을 미확정으로 구분한다',64,598,1152,65,25,C.gold);
 note(s,'원본 docs/synopsis-v0.1.md, docs/decisions.md, 기존 PPT·DOCX와 Figma는 삭제하지 않는다. 이전 합의 기록과 현재 인수인계가 다른 상태를 명시하며 상세안을 임의 폐기하거나 현재 사양으로 자동 채택하지 않는다.');
}
{
 const s=sl(10,'다음 설계와 개발 방향');
 txt(s,'fixed','설계 기준',64,169,530,60,32,C.gold,true);
 txt(s,'fixed-list','지도 중심의 역사 경험\n선사시대부터 이어지는 흐름\n역사와 지리의 자연스러운 학습\n사실·해석·게임 가정의 구분',64,250,530,230,28,C.text);
 txt(s,'next','다음 결정',686,169,530,60,32,C.gold,true);
 txt(s,'next-list','기본 반복 행동과 플레이어 역할\n목표·보상·시대 진행 조건\n지도와 실제 플레이의 관계\nReact·TypeScript 기반 구현 범위',686,250,530,230,28,C.text);
 txt(s,'figma','Figma 검토 범위',64,549,1152,48,29,C.gold,true);
 txt(s,'scope','메인 · 지도 · 시대 선택·진행 · 국가·지역 정보 · 역사 이벤트',64,609,1152,56,26,C.text);
 note(s,'Figma 기존 파일 https://www.figma.com/design/zkbflw9fCdAlWbphhw5pSS . 별도 검토 페이지의 화면 구조는 사용자 합의 전이다. Node.js는 서버 필요성 결정 후 검토한다. 엔진·저장·멀티플레이는 미확정이다.');
}
const staging=path.join(workspaceDir,'work/ppt-build');await fs.mkdir(staging,{recursive:true});
for(const [i,s] of p.slides.items.entries()){const png=await p.export({slide:s,format:'png',scale:1});await fs.writeFile(path.join(staging,`slide-${String(i+1).padStart(2,'0')}.png`),new Uint8Array(await png.arrayBuffer()));}
const candidatePath=path.join(staging,'candidate.pptx');await(await PresentationFile.exportPptx(p)).save(candidatePath);
const skill=process.env.ROX_PRESENTATION_SKILL;
const {finalizePresentation}=await import(pathToFileURL(path.join(skill,'container_tools/artifact_tool_utils.mjs')).href);
const result=await finalizePresentation({workspaceDir,candidatePath,finalPath:path.join(repo,'presentations/RoxHistory_Overview_v0.1-handover.pptx'),pythonExecutable:process.env.CODEX_PRIMARY_RUNTIME_PYTHON,integrityValidatorPath:path.join(skill,'container_tools/inspect_presentation_package_integrity.py'),layoutValidatorPath:path.join(skill,'container_tools/inspect_presentation_layout_geometry.py'),layoutArgs:['--expected-slide-size-emu','12192000,6858000','--validate-bullet-geometry','--validate-heading-fit','--require-native-table-slide','2','--require-native-table-slide','7','--require-native-table-slide','9'],explicitTotalSlideCount:10,requiredNativeTableOwnerSlides:[2,7,9],requiredNativeChartOwnerSlides:[],fontPolicy:{basis:'design',families:[font]},verifyArtifactToolImport:true,receiptPath:path.join(staging,'validation.json')});
console.log(JSON.stringify(result));
