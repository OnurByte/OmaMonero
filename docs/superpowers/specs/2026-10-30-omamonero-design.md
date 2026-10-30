# OmaMonero: Rust + Omarchy Quattro

GitHub'daki resmi Omarchy kaynaklarını, eklenti sözleşmesini ve Rust kullanan topluluk eklentilerini inceledim. OmaMonero'yu sıfırdan farklı bir uygulamaya çevirmeye gerek yok. Önceki modülleri koruyup çekirdeği Rust'a, arayüzü Omarchy'nin kendi Quickshell bileşenlerine ayırmalıyız.

Buradaki en önemli karar: OmaMonero, Omarchy'nin içine sonradan yapıştırılan bir widget değil, resmi `omarchy plugin` yaşam döngüsüne uyan bir eklenti olacak.

## 1. GitHub araştırmasında öne çıkan projeler

| Kaynak                                                                                                                      | OmaMonero için çıkarım                                                    |
| --------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------- |
| [Omarchy Shell Reference](https://github.com/omacom/omarchy/blob/quattro/docs/omarchy-shell.md?utm_source=chatgpt.com)      | Asıl manifest, IPC ve eklenti sözleşmesi                                  |
| [Shell Development Guide](https://github.com/omacom/omarchy/blob/quattro/agents/skills/shell-dev.md?utm_source=chatgpt.com) | Çoklu monitör, süreç yönetimi ve polling kuralları                        |
| [obsidian-daily-qs](https://github.com/LucaNerlich/obsidian-daily-qs?utm_source=chatgpt.com)                                | Rust backend + JSON akışı + Quickshell widget                             |
| [ai-usagebar](https://github.com/akitaonrails/ai-usagebar?utm_source=chatgpt.com)                                           | Rust binary ve Omarchy frontend'ini ayrı dağıtma                          |
| [OmaKeys](https://github.com/skvggor/omakeys-omarchy-plugin?utm_source=chatgpt.com)                                         | Rust daemon + dosya izleme + durum modeli                                 |
| [Gupax](https://github.com/gupax-io/gupax?utm_source=chatgpt.com)                                                           | Monero node, XMRig ve P2Pool entegrasyon örneği                           |
| [monero-rpc-rs](https://github.com/monero-rs/monero-rpc-rs?utm_source=chatgpt.com)                                          | Rust Monero RPC istemcisi                                                 |
| [Cuprate](https://github.com/Cuprate/cuprate?utm_source=chatgpt.com)                                                        | Rust Monero node mimarisi; alternatif node desteği için gelecek referansı |

`obsidian-daily-qs` özellikle benzer bir yaklaşım uyguluyor: Rust tarafı veriyi üretiyor, QML tarafı bar ve paneli yönetiyor. `ai-usagebar` ise Omarchy plugin yöneticisinin Rust binary'sini otomatik kurmadığı gerçeğini doğru ele alıyor.&#x20;

[image](https://www.google.com/s2/favicons?domain=https://github.com\&sz=32)

GitHub+2



## 2. Nihai mimari

Omarchy / Quickshell

BarWidget.qml · Panel.qml · Native UI kit

JSON state + explicit commands

omamonero-core

Rust · Tokio · Serde · systemd --user

Monero Node

monerod / Cuprate

Privacy Guard

Tor / I2P

Wallet Adapter

Watch-only RPC

Mining Adapter

XMRig / P2Pool

Burada iki ayrı yaşam döngüsü var.

Quickshell, yalnızca arayüzü yükler. Rust daemon, Monero bağlantılarını ve durum hesaplamalarını yönetir. Omarchy kapansa veya shell yeniden başlatılsa bile Rust servisinin davranışı öngörülebilir kalır.

İlk sürümde Rust daemon durumu `$XDG_RUNTIME_DIR/omamonero/status.json` dosyasına atomik biçimde yazacak. QML, `FileView` üzerinden değişiklikleri dinleyecek.

Böylece her monitörde ayrı RPC bağlantısı veya zamanlayıcı üzerinden tekrar tekrar komut çalıştırılması önlenecek. Bu doğrudan Omarchy'nin kendi shell geliştirme rehberindeki performans yaklaşımına uyuyor.&#x20;

[image](https://www.google.com/s2/favicons?domain=https://github.com\&sz=32)

GitHub+1



## 3. Omarchy plugin standartları

Bunları proje için değişmez uyumluluk koşulları olarak belirleyelim:

- `manifest.json` depo kökünde olacak; `schemaVersion: 1`, namespaced ID, `kinds` ve doğru `entryPoints` bulunacak.
- `omarchy.*` ad alanına dokunulmayacak. Önerilen ID: `io.github.onurbyte.omamonero`.
- İlk sürüm yalnızca `bar-widget` tanımlayacak. İçeride açılan panel ikinci bir `panel` türü olarak kaydedilmeyecek.
- Yeni `ShellRoot` veya ikinci bir Quickshell süreci başlatılmayacak.
- Arayüzde Omarchy'nin `BarWidget`, `WidgetButton`, `Panel`, `KeyboardPanel`, `PanelKeyCatcher` ve tema bileşenleri kullanılacak.
- Kurulum sırasında otomatik root yetkisi, kurulum hook'u, shell dosyası değiştirme veya zorunlu servis çalıştırma olmayacak.
- Eklenti klasöründe symlink bulunmayacak; plugin manager'ın etkinleştirme, devre dışı bırakma, güncelleme ve kaldırma mekanizmaları bozulmayacak.

Bunlar resmi Quattro sözleşmesiyle uyumlu; QML bileşenlerinin en son kaynak koddaki imzaları uygulama sırasında ayrıca kontrol edilmeli.&#x20;

[image](https://www.google.com/s2/favicons?domain=https://plugins.omarchy.org\&sz=32)

Omarchy Plugins+2



### Önerilen gerçek manifest

```

{
  "schemaVersion": 1,
  "id": "io.github.onurbyte.omamonero",
  "name": "OmaMonero",
  "version": "0.1.0",
  "author": "OnurByte",
  "license": "MIT",
  "description": "A privacy-first Monero companion for Omarchy.",
  "kinds": ["bar-widget"],
  "entryPoints": {
    "barWidget": "qml/BarWidget.qml"
  },
  "barWidget": {
    "displayName": "OmaMonero",
    "category": "System",
    "allowMultiple": false,
    "defaultSection": "right",
    "defaults": {
      "showBalance": false
    },
    "schema": [
      {
        "key": "showBalance",
        "type": "boolean",
        "label": "Show balance",
        "defaultValue": false
      }
    ]
  }
}

```

Bu, hedef manifest taslağı. Omarchy üzerinde henüz çalıştırılıp doğrulanmış bir dosya değil.

## 4. Önceki modülleri nasıl güçlendireceğiz?

| Modül            | Yeni yaklaşım                                                                          |
| ---------------- | -------------------------------------------------------------------------------------- |
| Monero Radar     | Node sağlık durumu, sync, block height, target height, disk kullanımı, ağ ayrımı       |
| Node Cockpit     | RPC gecikmesi, peer analizi, incoming/outgoing peer ayrımı, daemon sürümü, hatalar     |
| Privacy Guard    | Tor/I2P proxy konfigürasyonu, aktif rota denetimi, bağlantı politikasının doğrulanması |
| Quick Receive    | Başlangıçta mevcut public adres, sonra watch-only subaddress ve yerel QR               |
| Payment Radar    | Watch-only wallet RPC, onay sayısı ve yalnızca yerel bildirimler                       |
| Payment Proof    | İşlem doğrulaması; harcama yetkisi olmadan                                             |
| Mining Dashboard | XMRig/P2Pool durum ve hashrate bilgileri                                               |
| Wallet Launcher  | Feather ve Monero GUI'yi açma; private key erişimi olmadan                             |

Önemli ayrım: Watch-only cüzdan harcama yapamaz ama private view key yine gizli bilgidir. Ayrıca outgoing işlemleri tam göremediğinden bakiyeyi her zaman doğru hesaplayamayabilir. Bu yüzden Payment Radar'ı node izleme kodundan izole etmek gerekiyor.&#x20;

[image](https://www.google.com/s2/favicons?domain=https://web.getmonero.org\&sz=32)

Monero - secure, private, untraceable+1



Monero RPC için ilk sürümde `tokio`, `serde`, `serde_json`, `reqwest`, `tracing` ve `thiserror` yeterli olabilir. `monero-rpc-rs` iyi bir referans fakat bütün kitaplığı zorunlu bağımlılık yapmak yerine ihtiyacımız olan RPC metodlarını tipli, dar bir istemciyle yazmak daha kontrollü olacaktır.&#x20;

[image](https://www.google.com/s2/favicons?domain=https://github.com\&sz=32)

GitHub+1



## 5. Proje dizin yapısı

```

OmaMonero/
├── manifest.json
├── qml/
│   ├── BarWidget.qml
│   ├── Panel.qml
│   └── components/
│       ├── NodeStatus.qml
│       ├── PrivacyStatus.qml
│       └── SyncProgress.qml
├── src/
│   ├── main.rs
│   ├── app.rs
│   ├── config.rs
│   ├── rpc/
│   │   ├── daemon.rs
│   │   └── wallet.rs
│   ├── privacy/
│   │   ├── tor.rs
│   │   └── i2p.rs
│   ├── mining/
│   │   ├── xmrig.rs
│   │   └── p2pool.rs
│   ├── state/
│   │   ├── snapshot.rs
│   │   └── writer.rs
│   └── cli/
│       └── doctor.rs
├── packaging/
│   ├── omamonero.service
│   └── PKGBUILD
├── tests/
├── docs/
├── .github/workflows/
├── Cargo.toml
├── Cargo.lock
└── README.md

```

### Dağıtım kararı

İki parçalı dağıtım seçiyorum: resmi Omarchy plugin yöneticisiyle yüklenen QML frontend'i ve ayrı paketlenen Rust binary'si. Rust için AUR paketi hazırlayabiliriz; kaynak koddan `cargo install` da desteklenebilir.

Bu yaklaşımın avantajı, `omarchy plugin remove` işleminin Rust servisini yanlışlıkla silmeye veya özel kullanıcı verilerini bozmaya çalışmaması.

Backend bulunmazsa bar üzerinde açık bir `Backend not installed` durumu gösterilecek. Kurulum, onarım ve kaldırma kullanıcı tarafından açıkça gerçekleştirilecek.

## 6. Gizlilik ve dayanıklılık

OmaMonero'nun bazı durumlarda özellikle fail-closed davranması gerekiyor.

| Durum                             | Beklenen davranış                                         |
| --------------------------------- | --------------------------------------------------------- |
| Tor modu açık, proxy erişilemiyor | Dış ağa doğrudan bağlanma                                 |
| RPC zaman aşımına uğradı          | Eski veriyi güncelmiş gibi gösterme                       |
| Monerod kapandı                   | UI çalışmaya devam etsin, `Node offline` gözüksün         |
| Rust daemon çöktü                 | Shell etkilenmesin; systemd sınırlı yeniden başlatabilsin |
| Geçersiz JSON geldi               | Panel çökmesin, hata durumu gösterilsin                   |
| Birden fazla monitör var          | Tek backend, monitör başına yalnızca görüntüleme          |
| Eklenti güncellendi               | API sürüm uyuşmazlığını açıkça bildir                     |
| Shell yeniden başladı             | Servisi ikinci kez başlatma                               |
| Kullanıcı plugin'i kaldırdı       | Kullanıcı verisini kendiliğinden silme                    |

Soket ve durum dosyaları yalnızca kullanıcıya açık olacak (`0700` dizin, `0600` dosya). Servis varsayılan olarak RPC sunucusu açmayacak; gerektiğinde Unix domain socket kullanılabilecek.

`Privacy Guard` tarafında da yalnızca Tor sürecinin çalıştığını tespit etmek yeterli değil. Durum göstergesi, bağlantının gerçekten istenen rota politikasından geçtiğine ilişkin doğrulanmış bilgi ile yalnızca yapılandırılmış proxy bilgisini birbirinden ayırmalı.

## 7. Geliştirme sırası

v0.1 · Native Companion

Rust daemon, monerod RPC, bar widget, açılır panel, sağlık göstergeleri, shell yaşam döngüsü, CLI doctor. Gerçek Omarchy uyumluluğunu önce burada kanıtlayacağız.

v0.2 · Privacy & Payments

Tor/I2P politika kontrolleri, watch-only adapter, QR, subaddress, gelen ödeme izleme, yerel bildirimler.

v0.3 · Sovereign Dashboard

XMRig/P2Pool, mining telemetrisi, gelişmiş node tanılama, işlem kanıtları ve yerel geçmiş.

## 8. CI ve uyumluluk testleri

Resmi Omarchy doğrulayıcısıyla başlamalıyız:

```
omarchy plugin validate .
qmllint -I "$OMARCHY_PATH/shell" \
  qml/BarWidget.qml qml/Panel.qml

cargo fmt --all -- --check
cargo clippy --workspace --all-targets -- -D warnings
cargo test --workspace --locked
```

Bunun üzerine Quattro'da gerçek oturum testleri eklenmeli: panel aç/kapat, Escape, klavye ile gezinme, temayı değiştirme, farklı ekran ölçekleri, çoklu monitör, uyku/uyanma, plugin disable/enable ve hot reload.

Özellikle `FileView` ile atomik durum dosyası güncellemelerinin değişiklik olaylarını kaçırıp kaçırmadığını test etmeliyiz. Bu doğrulanmadan dosya izleme mekanizmasını tamamlanmış kabul etmem.

GitHub Actions tarafında ayrıca `cargo audit`, bağımlılık incelemesi, manifest/Cargo sürüm eşitleme ve reproducible build kontrollerini ekleriz.

## Son teknik karar

OmaMonero'nun hedefi Rust ile yazılmış bağımsız bir Monero uygulamasına Omarchy arayüzü takmak değil; Omarchy'nin doğal bir bileşeni gibi davranan, Rust destekli bir Monero kontrol merkezi oluşturmak.

Resmi Quattro standardına uyan QML frontend, dar yetkili Rust çekirdek, anahtarları tutmayan node-first güvenlik modeli ve sistemden bağımsız servis yaşam döngüsü bu projenin temelini oluşturmalı.

Bu araştırma tasarımı netleştiriyor; henüz çalışan bir eklenti veya test edilmiş bir Rust uygulaması üretmedim. Bir sonraki uygulama aşamasının kabul ölçütü de özellik sayısı değil, v0.1'in Omarchy plugin manager ile sorunsuz kurulup kaldırılması ve shell'i hiçbir hata durumunda etkilememesi olmalı.