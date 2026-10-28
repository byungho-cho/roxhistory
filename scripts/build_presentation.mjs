import fs from 'node:fs/promises';
import path from 'node:path';
import {pathToFileURL,fileURLToPath} from 'node:url';
import {buildDeck} from './deck-content.mjs';

const repo=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const workspaceDir=path.dirname(repo);
const modules=process.env.CODEX_PRIMARY_RUNTIME_NODE_MODULES;
const pkg=JSON.parse(await fs.readFile(path.join(modules,'@oai/artifact-tool/package.json'),'utf8'));
const {Presentation,PresentationFile}=await import(pathToFileURL(path.join(modules,'@oai/artifact-tool',pkg.exports['.'])).href);
const p=Presentation.create({slideSize:{width:1280,height:720}});
const sources=[];
for(let i=1;i<=3;i++){
  const b=await fs.readFile(path.join(repo,'assets',`visual-direction-${i}.png`));
  sources.push({blob:b.buffer.slice(b.byteOffset,b.byteOffset+b.byteLength),contentType:'image/png'});
}
await buildDeck(p,sources);
const staging=path.join(workspaceDir,'work-build','ppt');await fs.mkdir(staging,{recursive:true});
for(const [index,slide] of p.slides.items.entries()){
  const png=await p.export({slide,format:'png',scale:1});
  await fs.writeFile(path.join(staging,`slide-${String(index+1).padStart(2,'0')}.png`),new Uint8Array(await png.arrayBuffer()));
}
const candidate=path.join(staging,'candidate.pptx');await(await PresentationFile.exportPptx(p)).save(candidate);
const skill='/root/.codex/skills/builtins/presentations';
const {finalizePresentation}=await import(pathToFileURL(path.join(skill,'container_tools/artifact_tool_utils.mjs')).href);
const result=await finalizePresentation({workspaceDir,candidatePath:candidate,finalPath:path.join(repo,'presentations','RoxHistory_Overview_v0.1.pptx'),pythonExecutable:process.env.CODEX_PRIMARY_RUNTIME_PYTHON,integrityValidatorPath:path.join(skill,'container_tools/inspect_presentation_package_integrity.py'),layoutValidatorPath:path.join(skill,'container_tools/inspect_presentation_layout_geometry.py'),layoutArgs:['--expected-slide-size-emu','12192000,6858000','--validate-bullet-geometry','--validate-heading-fit','--require-native-table-slide','3','--require-native-table-slide','8'],explicitTotalSlideCount:10,requiredNativeTableOwnerSlides:[3,8],requiredNativeChartOwnerSlides:[],fontPolicy:{basis:'design',families:['Noto Sans CJK KR']},verifyArtifactToolImport:true,receiptPath:path.join(staging,'validation.json')});
console.log(JSON.stringify(result));
