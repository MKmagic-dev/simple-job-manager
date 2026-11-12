# Przekazanie aplikacji Simple Job Manager

Ten dokument opisuje, co należy do Ciebie po przekazaniu aplikacji, w jakiej
kolejności to uruchomić i co jeszcze trzeba zrobić, zanim aplikacja trafi do
Google Play. Nie wklejaj haseł ani kluczy do czatu ani e-maila. Trzymaj je w
menedżerze haseł (np. Bitwarden, 1Password albo wbudowanym w Chrome).

## 1. Co przekazujesz

Klientka ma już swoją stronę i domenę, więc ich nie ruszasz. Przekazujesz
tylko kod i bazę danych. Klientka zakłada własne konta w Supabase i na GitHubie,
a Ty przenosisz do nich projekt i repozytorium.

| Element | Gdzie jest teraz | Co zrobić |
|---|---|---|
| Projekt bazy danych | Supabase (`simple-job-manager`, organizacja MKmagic-dev) | Klientka zakłada konto Supabase, Ty przenosisz projekt do jej organizacji (Settings → General → Transfer project) |
| Kod aplikacji | GitHub `MKmagic-dev/simple-job-manager` | Klientka zakłada konto GitHub, Ty przenosisz repozytorium (Settings → Danger zone → Transfer ownership) |
| Domena `simplejobmanager.com` | jest jej | Nic nie przenosisz. Jeśli domena jest w Twoim Namecheap, klientka potrzebuje dostępu albo transferu do siebie |
| Strona WordPress (EasyWP) | jest jej | Nic nie przenosisz |
| Konto Google Play | nie istnieje | Klientka zakłada konto developera |
| Poczta wysyłkowa (np. Resend) | nie istnieje | Klientka zakłada konto i konfiguruje domenę |

Przeniesienie projektu Supabase nie usuwa danych. Baza jest już pusta, bo
wszystkie testowe konta i firmy zostały usunięte.

## 2. Kolejność

1. **Konta klientki.** Zakłada konta Supabase i GitHub na swój e-mail.
2. **Przeniesienie bazy (Supabase).** Przenosisz projekt do organizacji
   klientki. Potem sprawdza w Settings → API adres projektu i klucz `anon`.
3. **Przeniesienie kodu (GitHub).** Przenosisz repozytorium do konta klientki.
   Ona wpisuje w Settings → Secrets and variables → Actions:
   - `SUPABASE_URL` (adres projektu z Supabase),
   - `SUPABASE_ANON_KEY` (klucz `anon`).
   Bez nich build nie wykona się poprawnie.
4. **Funkcje serwerowe (Supabase → Edge Functions).** Klientka wdraża funkcje z
   katalogu `supabase/functions`: `register-company`, `create-employee`,
   `remove-employee`. Każda ma w komentarzu instrukcję, jak wdrożyć ją przez
   edytor w przeglądarce.
5. **Migracje bazy (Supabase → SQL Editor).** Uruchamia po kolei wszystkie pliki
   z `supabase/migrations` od najstarszego do najnowszego. Jeśli projekt został
   przeniesiony już z wynikami, sprawdza tylko te, których nie uruchamiano.
6. **E-mail (SMTP).** Bez tego nie działa reset hasła ani przyszłe kody do
   usuwania firmy. Patrz punkt 4 poniżej.
7. **Strona.** Klientka uzupełnia stronę `/privacy/` w WordPressie tekstem
   polityki prywatności.

## 3. Google Play (zrób dopiero po punktach 1–5)

- Załóż konto developera w Google Play Console (opłata jednorazowa 25 USD,
  weryfikacja tożsamości; może potrwać kilka dni).
- Jeśli konto jest osobiste i nowe, Google wymaga, żeby aplikacja najpierw
  przeszła test zamknięty z co najmniej 12 testerami przez 14 dni, zanim trafi
  do publicznej wersji. Sprawdź to w panelu przy zakładaniu aplikacji.
- Klucz podpisu zarządza Google (Play App Signing). Nie musisz trzymać klucza
  wydania sama.
- Wypełnij: opis i ikonę, zrzuty ekranu, deklarację wieku, formularz
  bezpieczeństwa danych, link do polityki prywatności.
- Build do wysłania: plik AAB z GitHub Actions (workflow „Build Android APK"
  robi APK; do sklepu potrzebny jest AAB, to osobny krok do ustalenia).

## 4. E-mail: serwer wysyłki (Resend lub inny)

1. Załóż konto u dostawcy poczty na swój adres (np. Resend).
2. Dodaj domenę wysyłkową, np. `send.simplejobmanager.com`.
3. Dodaj rekordy DNS w Namecheap (Advanced DNS) dokładnie tak, jak poda
   dostawca. Główny rekord SPF strony (`@`) zostaw bez zmian.
4. Gdy dostawca pokaże „Verified", wpisz dane SMTP w Supabase:
   Authentication → SMTP Settings.
5. W Authentication → URL Configuration ustaw Site URL na
   `https://simplejobmanager.com` i dodaj ten sam adres do Redirect URLs.

## 5. Co jeszcze nie jest zrobione w kodzie

- **Usuwanie całej firmy z kodem na e-mail.** Pomysł jest uzgodniony, ale
  kod nie jest napisany. Wymaga wcześniej działającego SMTP (punkt 4).
- **Usuwanie konta przez pracownika** nie jest dostępne. Pracownik nie usuwa
  konta sam, robi to szef przez „Usuń z zespołu".
- **Polityka prywatności i warunki** wymagają zatwierdzenia przez osobę
  odpowiedzialną za firmę, najlepiej po konsultacji prawnej.

## 6. Bezpieczeństwo po przeniesieniu

- Usuń swój dostęp do Supabase i GitHuba, jeśli nie chcesz zostawić sobie wglądu.
- Zmień hasła, które były w czatach i e-mailach (klucze API Supabase można
  zresetować w Settings → API).
- Darmowy plan Supabase nie ma kopii zapasowych z przywracaniem. Gdy aplikacja
  zacznie działać na prawdziwych danych, warto przejść na plan płatny.
