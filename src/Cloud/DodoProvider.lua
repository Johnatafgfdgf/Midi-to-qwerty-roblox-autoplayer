local D={}
function D.new(R,FS,options)
 local provider=R('Cloud/CloudProvider').new(nil,options)
 provider.lastError='Dodo Cloud indisponível: autenticação/contrato de serviço não validados para este cliente. Biblioteca local disponível.'
 return provider
end
return D
