# LM Studio AHC — Automatic Hardware Configuration

Instalador e configurador **multi-distribuição** para o [LM Studio](https://lmstudio.ai/), pensado principalmente para máquinas com recursos limitados.

O projeto **AHC (Automatic Hardware Configuration)** detecta o hardware e os recursos disponíveis antes de sugerir uma configuração de inferência local.

> **Status:** primeira versão experimental. Teste em uma máquina não crítica antes de usar em produção.

## Objetivo

A ideia do AHC não é simplesmente instalar o LM Studio.

O objetivo é:

1. detectar a distribuição Linux;
2. detectar arquitetura, CPU, AVX/AVX2, RAM e Swap;
3. detectar GPU e Vulkan quando possível;
4. instalar as dependências mínimas para o AppImage;
5. instalar o LM Studio em espaço de usuário;
6. oferecer perfis **Mínimo**, **Recomendado** e **Personalizado**;
7. usar `lms` para baixar modelos GGUF;
8. executar `--estimate-only` antes de carregar o modelo;
9. carregar o modelo somente depois da confirmação do usuário.

## Distribuições

O script possui lógica para as seguintes famílias:

- Debian / Ubuntu e derivados
- Fedora e derivados
- openSUSE e derivados
- Arch Linux e derivados

Exemplos de derivados detectados incluem Linux Mint, Pop!_OS, Zorin, Nobara, Manjaro, EndeavourOS e BIG Linux.

A compatibilidade real depende do AppImage, do driver gráfico e das bibliotecas disponíveis no sistema.

## Requisitos

- Linux 64-bit (`x86_64` ou `aarch64/arm64`)
- usuário normal com acesso a `sudo` quando dependências precisam ser instaladas
- conexão com a Internet durante download do LM Studio/modelos
- GPU/Vulkan é desejável, mas o objetivo é também permitir uso em CPU

O LM Studio para Linux é distribuído como AppImage. Consulte os requisitos e downloads oficiais antes de usar:

- https://lmstudio.ai/docs/app/system-requirements
- https://lmstudio.ai/download
- https://lmstudio.ai/docs/cli

## Instalação

Clone o repositório:

```bash
git clone https://github.com/elppans/lm-studio-install.git
cd lm-studio-install
```

Dê permissão:

```bash
chmod +x install-lmstudio-ahc.sh
```

Execute como usuário normal:

```bash
./install-lmstudio-ahc.sh
```

**Não execute como `root`.**

## O que o AHC detecta

Exemplo de informações utilizadas:

```text
Sistema
Família da distribuição
Arquitetura
Kernel
CPU
Threads
AVX
AVX2
RAM total
RAM disponível
Swap total
Swap utilizada
GPU
Vulkan
```

A memória disponível é obtida a partir de `MemAvailable`, em vez de usar apenas `MemFree`.

Isso é importante porque o Linux pode liberar cache quando um processo precisa de memória.

## Perfis

### Mínimo

Para máquinas com pouca memória ou para priorizar simplicidade:

```text
Modelo:       Qwen3 1.7B
Quantização:  Q4_K_M
Contexto:     2048
Parallel:     1
GPU:          Auto
Reasoning:    OFF
```

### Recomendado

Para usar o mesmo modelo com capacidade de raciocínio:

```text
Modelo:       Qwen3 1.7B
Quantização:  Q4_K_M
Contexto:     2048
Parallel:     1
GPU:          Auto
Reasoning:    ON
```

### Personalizado

Permite escolher:

- modelo;
- contexto;
- parallel;
- reasoning.

## Por que 1.7B / Q4_K_M?

O projeto é inicialmente voltado a computadores com aproximadamente 8 GB de RAM.

Durante os testes de referência, foi utilizado:

```text
CPU:       x86_64 / AVX2
RAM:       7.5 GiB
GPU:       Intel UHD Graphics (ICL GT1)
Vulkan:    disponível
Contexto:  2048
Parallel:  1
Modelo:    Qwen3 1.7B
```

O `lms load --estimate-only` informou:

```text
Estimated GPU Memory:   1.19 GiB
Estimated Total Memory: 1.19 GiB
```

O valor é uma estimativa do runtime e não uma garantia de consumo constante.

## Benchmark de referência

No hardware acima, com o modelo Qwen3 1.7B Q4_K_M:

### Carregamento

```text
Model loaded successfully in 19.04s.
```

### Reasoning ON

```text
Tokens/Second:       6.53
Time to First Token: 4.006s
Predicted Tokens:    144
```

### Reasoning OFF

```text
Tokens/Second:       6.84
Time to First Token: 2.554s
Predicted Tokens:    27
```

Esses números são apenas referências de uma máquina específica. Eles não devem ser tratados como benchmark universal.

Também foi observado que, quando o modelo já estava carregado, o tempo até o primeiro token de uma pergunta mais complexa chegou a:

```text
Time to First Token: 0.168s
Tokens/Second:        6.47
```

Isso demonstra a diferença entre **cold start** e **warm inference**.

## Swap

O AHC **não cria nem redimensiona Swap automaticamente**.

Isso é proposital.

Swap pode evitar falta imediata de memória, mas utilizar Swap intensivamente pode reduzir bastante o desempenho de inferência.

O script apenas informa a situação.

Exemplo:

```text
RAM disponível: 2.3 GiB
Swap:           3.9 / 4.0 GiB
```

Se a Swap estiver muito utilizada, recomenda-se fechar aplicativos desnecessários antes de carregar modelos.

## Instalação do LM Studio

O AppImage é colocado no espaço do usuário:

```text
~/.local/opt/lm-studio/LM-Studio.AppImage
```

Um launcher é criado em:

```text
~/.local/bin/lmstudio
```

E um atalho desktop em:

```text
~/.local/share/applications/lm-studio-ahc.desktop
```

O AHC não cria um serviço systemd para manter o LM Studio executando em segundo plano.

## Modelos

O AHC utiliza o CLI `lms` fornecido pelo LM Studio.

Exemplos:

```bash
lms ls
```

```bash
lms ps
```

```bash
lms runtime ls
```

```bash
lms runtime survey
```

Estimar um modelo:

```bash
lms load "qwen/qwen3-1.7b" \
    --context-length 2048 \
    --parallel 1 \
    --estimate-only
```

Carregar:

```bash
lms load "qwen/qwen3-1.7b" \
    --context-length 2048 \
    --parallel 1 \
    -y
```

Descarregar:

```bash
lms unload "qwen/qwen3-1.7b"
```

Testar:

```bash
lms chat "qwen/qwen3-1.7b" \
    --dont-fetch-catalog \
    --stats \
    --reasoning off \
    -p "Explique em uma frase o que é Linux."
```

## Remoção

Execute:

```bash
chmod +x uninstall-lmstudio-ahc.sh
./uninstall-lmstudio-ahc.sh
```

O desinstalador remove o AppImage e os arquivos criados pelo AHC.

**Os modelos não são removidos automaticamente.**

Isso evita apagar vários gigabytes de modelos sem confirmação explícita.

## Segurança e alterações no sistema

O AHC foi projetado para ser conservador.

Ele **não** altera automaticamente:

- regras de firewall;
- `/etc/sysctl.conf`;
- governor da CPU;
- parâmetros do kernel;
- serviços systemd;
- configurações de rede;
- Swap existente.

Dependências ausentes podem ser instaladas pelo gerenciador de pacotes da distribuição usando `sudo`.

## Limitações atuais

A primeira versão ainda possui limitações:

- a detecção de GPU/Vulkan depende das ferramentas disponíveis;
- o download automático do AppImage depende da página oficial permitir a descoberta da URL;
- modelos e quantizações disponíveis no catálogo podem mudar;
- a recomendação de modelo ainda é conservadora e baseada principalmente em recursos;
- o AHC ainda não faz benchmark automático de todos os modelos candidatos;
- o perfil recomendado atualmente usa o mesmo modelo pequeno do perfil mínimo em máquinas de baixa memória.

## Próximas etapas

Planejamento do projeto:

- [ ] melhorar a descoberta da URL do AppImage;
- [ ] detectar melhor Intel / AMD / NVIDIA;
- [ ] detectar VRAM e memória compartilhada;
- [ ] consultar `lms runtime survey` automaticamente;
- [ ] comparar `--estimate-only` com a RAM disponível;
- [ ] gerar recomendações de modelos por faixa de RAM;
- [ ] testar Q3/Q4/Q5 quando apropriado;
- [ ] benchmark automático após instalação;
- [ ] detectar e configurar Reasoning;
- [ ] gerar relatório final;
- [ ] adicionar modo `--dry-run`;
- [ ] adicionar modo não interativo para automação;
- [ ] melhorar suporte a ARM64;
- [ ] testes específicos por distribuição.

## Desenvolvimento

Executar com rastreamento:

```bash
bash -x ./install-lmstudio-ahc.sh
```

Isso é útil para diagnóstico, mas **não é necessário para uso normal**.

Uso normal:

```bash
./install-lmstudio-ahc.sh
```

## Licença

Escolha a licença do projeto conforme sua preferência. Para software livre permissivo, MIT é uma opção simples.

---

Projeto: https://github.com/elppans/lm-studio-install
