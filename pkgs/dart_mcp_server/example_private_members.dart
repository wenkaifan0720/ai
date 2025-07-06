// Example file to demonstrate skip_private functionality

class PublicWidget {
  String publicName = 'Public Widget';
  String _privateName = 'Private Widget';

  void showInfo() {
    print('Showing public info');
  }

  void _showPrivateInfo() {
    print('Showing private info');
  }
}

class _PrivateWidget {
  void display() {
    print('Private widget display');
  }
}

void main() {
  print('Main function');
}

void _helperFunction() {
  print('Private helper');
}

final publicConfig = {'key': 'value'};
final _privateConfig = {'secret': 'hidden'};
