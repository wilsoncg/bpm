# wget https://github.com/bpmn-io/bpmn-moddle

# build
# & (join-path ($profile | split-path) "vs2017.ps1")
# msbuild

xsd.exe .\BPMN20.xsd .\BPMNDI.xsd .\DC.xsd .\DI.xsd .\Semantic.xsd /classes /namespace:bpm /out:..\bpm-xsd\