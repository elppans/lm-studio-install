# LM Studio Minimal Install

Script Bash para preparar e otimizar uma instalação do **LM Studio no Ubuntu 22.04**, com foco em notebooks com recursos limitados, especialmente sistemas com **8 GB de RAM** e processadores Intel de baixo consumo.

O objetivo deste projeto é preparar o sistema para executar modelos de linguagem locais (**LLMs**) utilizando o menor consumo de recursos possível, evitando a instalação de componentes e serviços desnecessários.

> **Status do projeto:** funcional
> **Sistema principal:** Ubuntu 22.04
> **Arquitetura:** x86_64
> **Licença:** MIT

---

## 📋 Índice

* [Sobre o projeto](#-sobre-o-projeto)
* [Objetivos](#-objetivos)
* [Hardware de referência](#-hardware-de-referência)
* [Configuração recomendada](#-configuração-recomendada)
* [O que o script faz](#-o-que-o-script-faz)
* [O que o script não faz](#-o-que-o-script-não-faz)
* [Requisitos](#-requisitos)
* [Instalação](#-instalação)
* [Download do LM Studio](#-download-do-lm-studio)
* [Estrutura de diretórios](#-estrutura-de-diretórios)
* [Ferramenta de diagnóstico](#-ferramenta-de-diagnóstico)
* [Configuração recomendada no LM Studio](#-configuração-recomendada-no-lm-studio)
* [Swap e memória](#-swap-e-memória)
* [Swappiness](#-swappiness)
* [Remover as otimizações](#-remover-as-otimizações)
* [Desempenho esperado](#-desempenho-esperado)
* [Limitações](#-limitações)
* [Segurança](#-segurança)
* [Contribuições](#-contribuições)
* [Licença](#-licença)

---

# 🤖 Sobre o projeto

Este projeto fornece um script para preparar um ambiente Linux para utilização do **LM Studio** em computadores com hardware mais limitado.

A configuração foi pensada principalmente para notebooks com:

* 8 GB de RAM;
* processadores Intel de baixo consumo;
* GPU integrada;
* pouca disponibilidade de memória;
* necessidade de executar modelos locais de pequeno porte.

O foco é manter o sistema operacional funcional enquanto o modelo de IA está sendo executado, reduzindo a possibilidade de falta de memória e evitando serviços adicionais desnecessários.

O script não tenta transformar um hardware limitado em uma máquina de alto desempenho para IA. O objetivo é encontrar um equilíbrio entre:

* consumo de memória;
* consumo de CPU;
* estabilidade;
* velocidade;
* capacidade de execução de modelos locais.

---

# 🎯 Objetivos

O projeto busca fornecer uma configuração mínima e conservadora para executar o LM Studio.

Principais objetivos:

* Preparar o Ubuntu 22.04;
* Detectar informações básicas de hardware;
* Verificar a quantidade de RAM disponível;
* Identificar a GPU instalada;
* Verificar a existência de memória swap;
* Criar swap quando necessário;
* Configurar `vm.swappiness=10`;
* Criar uma estrutura organizada para o LM Studio;
* Criar scripts auxiliares;
* Criar um lançador no menu de aplicações;
* Evitar serviços rodando permanentemente em segundo plano;
* Evitar a instalação de componentes desnecessários;
* Fornecer uma configuração inicial adequada para computadores com pouca RAM.

---

# 💻 Hardware de referência

O script foi desenvolvido tendo como referência um notebook com configuração semelhante a:

| Componente            | Configuração         |
| --------------------- | -------------------- |
| Fabricante            | ASUS                 |
| Modelo                | VivoBook X515JA      |
| Processador           | Intel Core i3-1005G1 |
| Núcleos               | 2                    |
| Threads               | 4                    |
| Memória               | 8 GB DDR4            |
| Velocidade da memória | 3200 MT/s            |
| GPU                   | Intel integrada      |
| Sistema               | Ubuntu 22.04         |

O hardware de referência possui apenas **8 GB de RAM**, portanto o objetivo principal é executar modelos pequenos e manter o consumo de memória sob controle.

> O script pode ser utilizado em outros computadores, mas a configuração ideal pode variar de acordo com o hardware disponível.

---

# ⚙️ Configuração recomendada

Para computadores com aproximadamente 8 GB de RAM, a configuração inicial recomendada é:

| Parâmetro         | Valor  |
| ----------------- | ------ |
| Tamanho do modelo | 1B–2B  |
| Formato           | GGUF   |
| Quantização       | Q4_K_M |
| Context Length    | 2048   |
| CPU Threads       | 2      |
| GPU Offload       | Auto   |
| GPU Layers        | Auto   |

## Por que utilizar modelos 1B–2B?

Modelos menores exigem menos memória e tendem a ser mais adequados para computadores com recursos limitados.

A recomendação é começar com modelos entre **1B e 2B parâmetros** e avaliar o desempenho antes de tentar modelos maiores.

## Por que Q4_K_M?

A quantização **Q4_K_M** oferece um bom equilíbrio entre:

* tamanho do modelo;
* consumo de memória;
* velocidade;
* qualidade da resposta.

O objetivo é reduzir o consumo de recursos sem utilizar uma quantização excessivamente agressiva.

## Por que Context Length 2048?

O tamanho do contexto influencia diretamente o consumo de memória.

Em máquinas com apenas 8 GB de RAM, começar com:

```text
2048
```

é uma escolha conservadora.

Se o sistema estiver funcionando de forma estável, o usuário poderá experimentar valores maiores posteriormente.

## Por que apenas 2 CPU Threads?

O hardware de referência possui 2 núcleos e 4 threads.

A utilização inicial de 2 threads permite deixar recursos disponíveis para:

* Ubuntu;
* ambiente gráfico;
* navegador;
* terminal;
* outros processos do sistema.

Dependendo do hardware, utilizar 4 threads pode aumentar o desempenho, mas também pode tornar o sistema menos responsivo.

---

# 🔧 O que o script faz

O script `install-lmstudio-minimal_u2204.sh` executa as seguintes tarefas.

## 1. Verifica privilégios

O script não deve ser executado diretamente como `root`.

Ele utiliza `sudo` somente quando necessário.

Exemplo:

```bash
./install-lmstudio-minimal_u2204.sh
```

---

## 2. Verifica o sistema operacional

O script verifica se o sistema é Ubuntu e se a versão é a 22.04.

Caso seja detectado outro sistema ou outra versão, o usuário é avisado e pode decidir se deseja continuar.

---

## 3. Detecta o hardware

São coletadas informações básicas sobre:

* sistema operacional;
* kernel;
* processador;
* quantidade de threads;
* memória RAM;
* GPU.

Essas informações são exibidas durante a execução.

---

## 4. Instala dependências mínimas

O script instala apenas ferramentas básicas utilizadas pelo próprio processo:

```text
curl
wget
pciutils
procps
util-linux
```

Não são instalados:

* CUDA;
* Docker;
* Ollama;
* servidores adicionais;
* serviços systemd;
* ferramentas de monitoramento de temperatura;
* outros componentes que não sejam necessários para a configuração mínima.

---

## 5. Cria a estrutura do LM Studio

O diretório principal utilizado pelo projeto é:

```text
~/LMStudio
```

Dentro dele são criados:

```text
~/LMStudio/
├── config/
└── tools/
```

---

## 6. Verifica o Swap

O script verifica a quantidade de swap disponível no sistema.

Caso exista pelo menos 4 GB de swap, nenhuma alteração é feita.

Caso exista menos de 4 GB, o script oferece a possibilidade de criar um arquivo:

```text
/swapfile
```

com:

```text
8 GB
```

O swap não aumenta a velocidade do LM Studio.

Sua finalidade é fornecer uma área adicional de memória virtual e reduzir o risco de problemas quando a RAM física estiver completamente ocupada.

> O uso de swap é significativamente mais lento que a RAM física. Portanto, swap não substitui um upgrade de memória RAM.

---

## 7. Configura o Swappiness

O script cria:

```text
/etc/sysctl.d/99-lmstudio-minimal.conf
```

com:

```text
vm.swappiness=10
```

A configuração é aplicada imediatamente.

O objetivo é reduzir a tendência do kernel de utilizar swap enquanto ainda existe memória RAM disponível.

---

## 8. Cria recomendações de configuração

O arquivo:

```text
~/LMStudio/config/recomendacoes.txt
```

contém a configuração recomendada para o hardware de referência.

---

## 9. Cria ferramenta de diagnóstico

O script cria:

```text
~/LMStudio/tools/lmstudio-info.sh
```

Essa ferramenta mostra informações sobre:

* sistema operacional;
* kernel;
* CPU;
* RAM;
* swap;
* swappiness;
* GPU;
* carga do sistema;
* processos que mais utilizam memória.

---

## 10. Cria script de inicialização

O script:

```text
~/LMStudio/tools/lmstudio-start.sh
```

procura automaticamente por um arquivo:

```text
*.AppImage
```

dentro de:

```text
~/LMStudio
```

Se encontrar o AppImage, ele é executado.

---

## 11. Cria lançador no menu

É criado um arquivo `.desktop` em:

```text
~/.local/share/applications/
```

Isso permite iniciar o LM Studio pelo menu de aplicações do ambiente gráfico.

---

# ❌ O que o script não faz

O script **não instala automaticamente o LM Studio**.

O motivo é evitar depender de uma URL ou versão específica do AppImage.

O usuário deve baixar o LM Studio diretamente do site oficial e colocar o arquivo `.AppImage` no diretório:

```text
~/LMStudio
```

O script também não instala automaticamente modelos de IA.

Isso permite que cada usuário escolha o modelo que deseja utilizar.

---

# 📦 Requisitos

## Sistema operacional

Recomendado:

```text
Ubuntu 22.04
```

## Arquitetura

```text
x86_64
```

## Requisitos básicos

* Ubuntu instalado;
* acesso à Internet;
* usuário com privilégios `sudo`;
* aproximadamente 8 GB ou mais de RAM;
* espaço livre em disco para o LM Studio e os modelos.

---

# 🚀 Instalação

Clone o repositório:

```bash
git clone https://github.com/elppans/lm-studio-install.git
```

Entre no diretório:

```bash
cd lm-studio-install
```

Dê permissão de execução:

```bash
chmod +x install-lmstudio-minimal_u2204.sh
```

Execute:

```bash
./install-lmstudio-minimal_u2204.sh
```

O script solicitará confirmação antes de criar o swap, caso seja necessário.

---

# 📥 Download do LM Studio

Após executar o script, baixe o LM Studio para Linux diretamente do site oficial:

https://lmstudio.ai/

Baixe a versão para Linux compatível com seu sistema.

Coloque o arquivo `.AppImage` no diretório:

```text
~/LMStudio
```

Exemplo:

```text
~/LMStudio/LM-Studio-*.AppImage
```

Dê permissão de execução:

```bash
chmod +x ~/LMStudio/*.AppImage
```

Depois execute:

```bash
~/LMStudio/tools/lmstudio-start.sh
```

O LM Studio também poderá ser iniciado pelo menu de aplicações do sistema.

---

# 🗂️ Estrutura de diretórios

Após a execução do script, a estrutura será semelhante a:

```text
~/LMStudio/
├── config/
│   └── recomendacoes.txt
│
├── tools/
│   ├── lmstudio-info.sh
│   ├── lmstudio-start.sh
│   └── remove-lmstudio-tuning.sh
│
└── LM-Studio-*.AppImage
```

---

# 🔍 Ferramenta de diagnóstico

Para verificar o estado atual do sistema:

```bash
~/LMStudio/tools/lmstudio-info.sh
```

O comando exibirá informações semelhantes a:

```text
============================================================
LM STUDIO - DIAGNÓSTICO DO SISTEMA
============================================================

SISTEMA
------------------------------------------------------------

CPU
------------------------------------------------------------

MEMÓRIA
------------------------------------------------------------

SWAP
------------------------------------------------------------

SWAPPINESS
------------------------------------------------------------

GPU
------------------------------------------------------------

USO ATUAL
------------------------------------------------------------

PROCESSOS COM MAIOR CONSUMO DE RAM
------------------------------------------------------------
```

Essa ferramenta é útil para verificar se o sistema possui memória suficiente antes de carregar um modelo.

Também pode ser utilizada durante testes para identificar processos que estejam consumindo muita RAM.

---

# ⚙️ Configuração recomendada no LM Studio

Para o hardware de referência, recomenda-se começar com:

```text
Modelo:          1B–2B
Formato:         GGUF
Quantização:     Q4_K_M
Context Length:  2048
CPU Threads:     2
GPU Offload:     Auto
GPU Layers:      Auto
```

## Configuração inicial

Comece com:

```text
Context Length = 2048
CPU Threads    = 2
GPU Offload    = Auto
GPU Layers     = Auto
```

Evite inicialmente utilizar modelos muito grandes.

Em um sistema com 8 GB de RAM, não é recomendado começar diretamente com modelos de 7B ou 8B.

Primeiro teste um modelo de 1B ou 2B.

Depois, caso o sistema permaneça estável e exista memória disponível, outros modelos e configurações podem ser testados.

---

# 🧠 Swap e memória

A quantidade de RAM disponível é um dos principais fatores que limitam a execução de modelos locais.

Um sistema com:

```text
8 GB RAM
```

precisa dividir essa memória entre:

* kernel Linux;
* ambiente gráfico;
* aplicativos;
* LM Studio;
* modelo de IA;
* contexto do modelo;
* memória utilizada pela GPU integrada.

Em GPUs integradas, parte da memória gráfica também pode ser compartilhada com a memória principal do sistema.

Por isso, utilizar modelos pequenos é importante quando o objetivo é manter o computador responsivo.

O swap pode ajudar quando a memória RAM estiver esgotada, mas não deve ser considerado um substituto da RAM física.

---

# 🔄 Swappiness

O script configura:

```text
vm.swappiness=10
```

A configuração pode ser verificada com:

```bash
cat /proc/sys/vm/swappiness
```

Resultado esperado:

```text
10
```

O arquivo utilizado pelo projeto é:

```text
/etc/sysctl.d/99-lmstudio-minimal.conf
```

---

# 🧹 Remover as otimizações

O projeto fornece:

```bash
~/LMStudio/tools/remove-lmstudio-tuning.sh
```

Execute:

```bash
~/LMStudio/tools/remove-lmstudio-tuning.sh
```

Esse script remove a configuração:

```text
/etc/sysctl.d/99-lmstudio-minimal.conf
```

e restaura o comportamento padrão do `swappiness`.

Por segurança, o script **não remove automaticamente o `/swapfile`**.

Caso você tenha criado o swapfile pelo instalador e queira removê-lo manualmente:

```bash
sudo swapoff /swapfile
```

Remova a entrada correspondente de:

```text
/etc/fstab
```

Depois:

```bash
sudo rm -f /swapfile
```

> Tenha cuidado ao editar `/etc/fstab`. Remova somente a linha correspondente ao `/swapfile` criado por este projeto.

---

# 📊 Desempenho esperado

O desempenho de modelos locais depende de vários fatores:

* modelo utilizado;
* quantidade de parâmetros;
* quantização;
* tamanho do contexto;
* CPU;
* GPU;
* quantidade de RAM;
* velocidade da memória;
* aceleração disponível;
* temperatura do equipamento.

Este projeto não tem como objetivo maximizar o número de tokens por segundo.

O objetivo principal é obter uma configuração que permita utilizar modelos locais pequenos mantendo o sistema operacional utilizável.

Em hardware limitado, uma configuração mais conservadora pode proporcionar uma experiência melhor do que tentar carregar um modelo muito grande e provocar uso excessivo de RAM e swap.

---

# ⚠️ Limitações

Este projeto foi desenvolvido com foco em um cenário específico:

```text
Ubuntu 22.04
8 GB RAM
CPU Intel de baixo consumo
GPU integrada
```

Computadores com hardware diferente podem apresentar resultados diferentes.

O script não garante:

* aceleração por GPU;
* determinado número de tokens por segundo;
* compatibilidade com todos os modelos;
* execução de modelos grandes;
* funcionamento de todas as opções de aceleração disponíveis no LM Studio.

A disponibilidade de aceleração por GPU depende do hardware, dos drivers, do backend utilizado e da versão do LM Studio.

---

# 🔐 Segurança

O script não solicita a senha do usuário diretamente.

Quando necessário, utiliza o mecanismo padrão:

```bash
sudo
```

O usuário pode revisar o código antes de executar.

Recomenda-se sempre verificar scripts Bash obtidos da Internet antes de executá-los com privilégios administrativos.

Para visualizar o código:

```bash
less install-lmstudio-minimal_u2204.sh
```

Para verificar a sintaxe do script:

```bash
bash -n install-lmstudio-minimal_u2204.sh
```

O projeto não instala:

* mineradores;
* serviços ocultos;
* processos persistentes;
* Docker;
* Ollama;
* CUDA;
* servidores externos;
* serviços systemd adicionais.

---

# 🧪 Verificação antes da execução

Antes de executar o instalador:

```bash
bash -n install-lmstudio-minimal_u2204.sh
```

Se não houver nenhuma mensagem de erro, a sintaxe Bash está válida.

Depois:

```bash
chmod +x install-lmstudio-minimal_u2204.sh
```

E execute:

```bash
./install-lmstudio-minimal_u2204.sh
```

---

# 🤝 Contribuições

Sugestões, correções e melhorias são bem-vindas.

Se você encontrar um problema, abra uma **Issue** informando:

* versão do Ubuntu;
* modelo do processador;
* quantidade de RAM;
* GPU;
* saída de `~/LMStudio/tools/lmstudio-info.sh`;
* mensagem de erro apresentada pelo script.

Pull Requests também são bem-vindos.

---

# 📄 Licença

Este projeto está disponível sob a licença MIT.

Consulte o arquivo:

```text
LICENSE
```

para obter os termos completos da licença.

---

# ⭐ Considerações finais

Este projeto foi criado com o objetivo de facilitar a preparação de computadores com recursos limitados para utilização de IA local através do LM Studio.

A filosofia do projeto é simples:

> **Usar apenas o necessário, consumir o mínimo possível e manter o sistema estável.**

A configuração recomendada para começar é:

```text
1B–2B
Q4_K_M
Context 2048
CPU Threads 2
GPU Offload Auto
GPU Layers Auto
```

A partir dessa configuração, o usuário pode realizar seus próprios testes e aumentar gradualmente o tamanho do modelo ou o contexto conforme a capacidade do hardware.

---

## 🔗 Links

* **Repositório:** https://github.com/elppans/lm-studio-install
* **LM Studio:** https://lmstudio.ai/
* **LM Studio Downloads:** https://lmstudio.ai/download
